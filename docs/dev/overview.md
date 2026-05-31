# Development Overview

This repository follows a monorepo layout inspired by full-house.

## Areas

- server: Gleam backend
- client-web: SolidJS frontend
- skir-src: contract definitions
- container: container and runtime helpers

## Delivery Rule

Implement one vertical slice at a time.
A slice is done only when checks are green and the feature works end-to-end.

## Baseline Checks

- Backend: `./scripts/check_backend.sh`
- Frontend: `./scripts/check_frontend.sh`
- Combined: `./scripts/check_all.sh`

Backend quality includes a SQLite storage smoke check via
`./scripts/check_storage_smoke.sh`.

## Fast Local Hooks

- Install hooks once: `lefthook install`
- Pre-commit uses `lefthook.yml` with fast checks:
	- `./scripts/check_backend_fast.sh`
	- `./scripts/check_frontend_fast.sh`

Architecture dependency constraints are enforced by the backend lint gate.

Domain language and bounded contexts for Phase 2.1 are documented in
`docs/dev/domain-ubiquitous-language.md`.

Phase 2.4 introduces application ports in `server/src/application/*` and
infrastructure adapters in `server/src/infrastructure/*`.

Phase 3.2 starts request-to-application mapping handlers under
`server/src/driver/skir/*`.

Phase 3.3 introduces HTTP route and mapper scaffolding under
`server/src/driver/http/*`.
