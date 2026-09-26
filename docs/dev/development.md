# Development Guide

Everything needed to set up a working environment, run the service locally, and pass the quality gates. This is the single source of truth for developer workflow; README and AGENTS.md link here.

## Environment Setup (fresh clone / new machine)

1. `just dbmate-install` then `just dbmate-migrate` — SQLite migrations via dbmate; the db path comes from `TCG_DB_FILE` (`just server::run` sets it to `server/db/tcg-card-collector.db`). Some migrations request a catalog reset (adding a Scryfall-sourced column); after applying one, the next server start re-downloads the full catalog before the Catalog page shows a last-refresh entry again — a few minutes, not instant.
2. `lefthook install` — one-time, manual; pre-commit then runs the check suite on staged content.

This repo has only `AGENTS.md` files, no `CLAUDE.md`. Claude Code reads `AGENTS.md` natively from version 2.1.277 onward; on an older version, root and per-directory agent instructions won't load.

## Repository Layout

- `server` — Gleam backend (Erlang target)
- `client-web` — SolidJS/TypeScript web client
- `skir-src` — Skir contract source (code is generated for both sides)
- `container` — container/runtime assets
- `scripts` — helper scripts backing just recipes (dbmate install/run, skir snapshot check)
- `docs` — vision, architecture, decision records (ADRs), ubiquitous language, this guide

## Task Runner

`just` with `::` module scoping. Run `just --list` for the full list.

```sh
just dev              # run backend + frontend
just check            # all checks and tests (skir + server + client-web)
just server::test     # Gleam unit tests
just client-web::test # Vitest tests
just skir-gen         # regenerate code from skir-src/
```

## Quality Gates

- Backend: format, typecheck, unit tests, architecture lint
- Frontend: format, lint, typecheck, tests

Run locally:

- `just server::check` — backend static checks (format, typecheck, lint)
- `just client-web::check` — frontend static checks
- `just skir-check` — contract format + snapshot alignment
- `just test` — both test suites
- `just check` — all of the above

Individual checks:

- `just server::format-check`, `just server::type-check`, `just server::lint-check`
- `just client-web::format-check`, `just client-web::type-check`, `just client-web::lint-check`

## Git Hooks

Install with `lefthook install`. Pre-commit hooks run the full check suite on staged content.

## Building the container image locally

```sh
docker build -t tcg-cc-local .
docker run -d -p 8080:8080 -v tcg-dev-data:/data tcg-cc-local
```

## Versioning & Releases

`server/gleam.toml`'s `version` field is the **single source of truth** — nothing else declares it (`client-web/package.json` doesn't carry one, on purpose). The running server reads it back from the compiled Erlang application resource file and serves it over both `GET /api/version` and the Skir `GetAppVersion` method; the web UI shows it in the page footer.

A `main`-branch or local build is never mistaken for a release: the image is built with `APP_CHANNEL=dev`, which appends `-dev+<short sha>` (`-dev+local` for a plain `docker build` with no build args, and for `just dev`). A `v*`-tag build passes `APP_CHANNEL=release`, giving the bare version.

### Release notes

[`CHANGELOG.md`](../../CHANGELOG.md) is the source of truth for what a release changed and what it needs from someone upgrading. Any user-visible change (not internals, refactors, or dependency bumps) adds its line under `## Unreleased` in the same commit; cutting a release renames that heading to `## vX.Y.Z — YYYY-MM-DD`. Never create a version's section before cutting it — upgrade notes for a coming release go under `## Unreleased` too; `just changelog-section` prints only the first matching heading, so a second one silently drops content from the release notes. CI turns that section into the GitHub Release body — a tag with no matching section fails the build before an image is published.

### Cutting a release

1. `main` is ready: `just check` is green, the working tree is clean, and the `vX.Y.Z` milestone has no open issues. Two passes the checks can't do:
   - Read every migration since the last tag (`git diff --stat vPREV main -- server/db/migrations/`) for anything that can lose collection or inventory data; if one can, `### Upgrading` must say so (README § Data preservation).
   - Hunt doc–code drift over the release's changes (the `documentation` skill) — a removed feature tends to leave stale mentions behind.
2. Rename `## Unreleased` in `CHANGELOG.md` to `## vX.Y.Z — <today>`. Read the entries once as a self-hoster would — especially any `### Upgrading` block — and preview them the way CI will read them: `just changelog-section X.Y.Z`.
3. Confirm `version` in `server/gleam.toml` is already `X.Y.Z` (day-to-day development leaves it at the version being built toward). Commit the changelog rename and any version bump together.
4. `git tag vX.Y.Z`, then push `main` and the tag. This step stays manual by design — nothing pushes on your behalf.
5. CI verifies the tag against `server/gleam.toml` and against the `CHANGELOG.md` section, publishes the image tags (`X.Y.Z`, `X.Y`, `X`, `latest`), then creates the GitHub Release from that section.
6. Verify: the `X.Y.Z` tag is on [GHCR](https://ghcr.io/nicoviii/tcg-card-collector), the release page shows the notes, and the image reports the bare version (no `-dev+…` suffix): `docker run -d --rm --name release-check -p 18080:8080 ghcr.io/nicoviii/tcg-card-collector:X.Y.Z`, then `curl localhost:18080/api/version` once it's up, then `docker stop release-check`. Then close the `vX.Y.Z` milestone.
7. In a follow-up commit, bump `server/gleam.toml` to the next minor version and add a fresh empty `## Unreleased` heading to `CHANGELOG.md`. Bumping right away keeps `main` builds from reporting `X.Y.Z-dev+<sha>`, which semver sorts before the release they follow.
8. When scoping the next milestone, if it promises a major version, re-bump `server/gleam.toml` to match. Dev builds promise nothing, so the provisional minor guess costs nothing.

### Export format changes

A release imports every export `format_version` written by any release of its own major version or the previous one ([ADR 0020](../decisions/0020-export-format-compatibility.md)). Bumping `format_version` in `server/src/portability/domain/export_document.gleam`:

1. Add a new `decode_vN` in `server/src/portability/driver/export_file.gleam` alongside the existing per-version decoders — never edit a shipped one.
2. Add a frozen fixture, `server/test/portability/fixtures/format_v<N>.json` (`server/test/AGENTS.md`), and repoint the "current fixture" constant in `format_fixtures_test.gleam` so the byte-identical round-trip test covers the new version.
3. Update `docs/portability/export.schema.json` for the new shape; `just portability-schema-check` validates every fixture (old and new) against it.
4. Add the `CHANGELOG.md` line under `## Unreleased`.

Dropping support for an older `format_version` is a major-release action only, with a `### Upgrading` note telling anyone still on that format to re-export on their current version first.
