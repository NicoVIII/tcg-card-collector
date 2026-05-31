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
- Contract alignment: `./scripts/check_contract_alignment.sh`

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

Request-to-application mapping handlers are implemented under
`server/src/driver/skir/*`.

HTTP routes and mapper modules are implemented under
`server/src/driver/http/*`.

Unversioned contract compatibility policy is documented in
`docs/dev/contract-compatibility.md`.
