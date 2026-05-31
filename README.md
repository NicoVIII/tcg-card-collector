# tcg-card-collector

Self-hosted TCG collection service.

Planned stack:
- Backend: Gleam with DDD + hexagonal architecture
- Contract: Skir
- Frontend: SolidJS + TypeScript + TanStack Query

## Repository Layout

- server: Gleam backend
- client-web: Solid web client
- skir-src: Skir contract source
- container: container/runtime assets
- docs: project documentation

## Current Status

Phase 1 tooling baseline is in place.

## Quality Gates

- Backend: format, typecheck, unit tests, architecture lint
- Frontend: format, lint, typecheck, tests

Run locally:

- `./scripts/check_backend.sh`
- `./scripts/check_frontend.sh`
- `./scripts/check_all.sh`

## Developer Feedback Loop

- Install git hooks: `lefthook install`
- Pre-commit hooks run fast backend/frontend checks.
- You can run them directly:
	- `./scripts/check_backend_fast.sh`
	- `./scripts/check_frontend_fast.sh`
