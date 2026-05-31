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

- Backend: `just check-backend`
- Frontend: `just check-frontend`
- Combined: `just check-all`
- Contract alignment: `just contract-alignment-check`

Backend quality includes a SQLite storage smoke check via
`./scripts/check_storage_smoke.sh`.

## Fast Local Hooks

- Install hooks once: `lefthook install`
- Pre-commit uses `lefthook.yml` with fast checks:
  - `just backend-format-check`
  - `just backend-typecheck`
  - `just backend-architecture-lint`
  - `just frontend-format-check`
  - `just frontend-lint`
  - `just frontend-typecheck`

Architecture dependency constraints are enforced by the backend lint gate.

Domain language and bounded contexts are documented in
`docs/dev/domain-ubiquitous-language.md`.

Application ports are implemented in `server/src/application/*` and
infrastructure adapters in `server/src/infrastructure/*`.

Request-to-application mapping handlers are implemented under
`server/src/driver/skir/*`.

HTTP routes and mapper modules are implemented under
`server/src/driver/http/*`.

Unversioned contract compatibility policy is documented in
`docs/dev/contract-compatibility.md`.
