# Development Guide

Everything needed to set up a working environment, run the service locally, and pass the quality gates. This is the single source of truth for developer workflow; README and AGENTS.md link here.

## Environment Setup (fresh clone / new machine)

1. `git submodule update --init` — `server/vendor/gleam-libs` is required; `just server::lint-check` fails without it.
2. `just dbmate-install` then `just dbmate-migrate` — SQLite migrations via dbmate; the db path comes from `TCG_DB_FILE` (`just server::run` sets it to `server/db/tcg-card-collector.db`).
3. `lefthook install` — one-time, manual; pre-commit then runs the check suite on staged content.

## Repository Layout

- `server` — Gleam backend (Erlang target)
- `client-web` — SolidJS/TypeScript web client
- `skir-src` — Skir contract source (code is generated for both sides)
- `container` — container/runtime assets
- `docs` — vision, ubiquitous language, this guide

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
- Migrations: storage smoke test (CI + on demand; needs sqlite3 + dbmate)

Run locally:

- `just server::check` — backend checks (format, typecheck, lint)
- `just client-web::check` — frontend checks
- `just skir-check` — contract format + snapshot alignment
- `just check` — all of the above
- `just storage-smoke` — migration smoke test (not part of `just check`)

Individual checks:

- `just server::format-check`, `just server::type-check`, `just server::lint-check`
- `just client-web::format-check`, `just client-web::type-check`, `just client-web::lint-check`

## Git Hooks

Install with `lefthook install`. Pre-commit hooks run the full check suite on staged content.
