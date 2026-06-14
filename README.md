# tcg-card-collector

Self-hosted TCG collection service.

Stack:

- Backend: Gleam with DDD + hexagonal architecture
- Contract: Skir
- Frontend: SolidJS + TypeScript + TanStack Query

## Repository Layout

- server: Gleam backend
- client-web: Solid web client
- skir-src: Skir contract source
- container: container/runtime assets

## Current Status

MVP vertical slice is implemented end-to-end:

- Contract-first SkirRPC backend/frontend integration
- SQLite-backed persistence for catalog/import/inventory/settings
- Inventory projection from latest succeeded import run and saved rules
- Quality gates covering format/lint/typecheck/tests/storage smoke/contract checks

## Quality Gates

- Backend: format, typecheck, unit tests, architecture lint
- Frontend: format, lint, typecheck, tests

Run locally:

- `just server::check` — backend checks (format, typecheck, lint)
- `just client-web::check` — frontend checks
- `just skir-check` — contract format + snapshot alignment
- `just check` — all of the above

## Developer Feedback Loop

Install git hooks: `lefthook install`. Pre-commit hooks run the full check suite on staged content.

Individual checks:

- `just server::format-check`, `just server::type-check`, `just server::lint-check`
- `just client-web::format-check`, `just client-web::type-check`, `just client-web::lint-check`
