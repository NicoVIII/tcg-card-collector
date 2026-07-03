# AGENTS.md

## Project Scope

Self-hosted service for managing a Magic: The Gathering collection and planning its physical organization (catalog sync, collection import, location rules → projections). The MVP vertical slice is complete end-to-end. See [docs/vision.md](docs/vision.md) for goals, direction, and non-goals before judging whether a feature or design change is in scope.

## Stack

Gleam backend (Erlang target) + SolidJS/TypeScript frontend, connected by a Skir contract (contract-first RPC with code generation for both sides).

## Task Runner

`just` with `::` module scoping. Key commands:

```sh
just dev              # run backend + frontend
just check            # all checks (skir + server + client-web)
just server::test     # Gleam unit tests
just client-web::test # Vitest tests
just skir-gen         # regenerate code from skir-src/
```

Run `just --list` for the full list.

## Environment Setup (fresh clone / new machine)

- `git submodule update --init` — `server/vendor/gleam-libs` is required; `just server::lint-check` fails without it.
- `just dbmate-install` then `just dbmate-migrate` — SQLite migrations via dbmate; the db path comes from `TCG_DB_FILE` (`just server::run` sets it to `server/db/tcg-card-collector.db`).
- `lefthook install` — one-time, manual; pre-commit then runs the check suite on staged content.