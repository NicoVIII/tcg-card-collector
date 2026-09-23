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
just check            # all checks (skir + server + client-web)
just server::test     # Gleam unit tests
just client-web::test # Vitest tests
just skir-gen         # regenerate code from skir-src/
```

## Quality Gates

- Backend: format, typecheck, unit tests, architecture lint
- Frontend: format, lint, typecheck, tests

Run locally:

- `just server::check` — backend checks (format, typecheck, lint)
- `just client-web::check` — frontend checks
- `just skir-check` — contract format + snapshot alignment
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

[`CHANGELOG.md`](../../CHANGELOG.md) is the source of truth for what a release changed and what it needs from someone upgrading. Any user-visible change (not internals, refactors, or dependency bumps) adds its line under `## Unreleased` in the same commit; cutting a release renames that heading to `## vX.Y.Z — YYYY-MM-DD`. CI turns that section into the GitHub Release body — a tag with no matching section fails the build before an image is published.

### Cutting a release

1. `just check` is green on `main` and the working tree is clean.
2. Rename `## Unreleased` in `CHANGELOG.md` to `## vX.Y.Z — <today>`. Read the entries once as a self-hoster would — especially any `### Upgrading` block — and preview them the way CI will read them: `just changelog-section X.Y.Z`.
3. Confirm `version` in `server/gleam.toml` is already `X.Y.Z` (day-to-day development leaves it at the version being built toward). Commit the changelog rename and any version bump together.
4. `git tag vX.Y.Z`, then push `main` and the tag. This step stays manual by design — nothing pushes on your behalf.
5. CI verifies the tag against `server/gleam.toml` and against the `CHANGELOG.md` section, publishes the image tags (`X.Y.Z`, `X.Y`, `X`, `latest`), then creates the GitHub Release from that section.
6. Verify: the `X.Y.Z` tag is on [GHCR](https://ghcr.io/nicoviii/tcg-card-collector), the release page shows the notes, and `docker run … :X.Y.Z` reports the bare version (no `-dev+…` suffix) at `/api/version`.
7. In a follow-up commit, bump `server/gleam.toml` to the next development version (see above for why) and add a fresh empty `## Unreleased` heading to `CHANGELOG.md`.
