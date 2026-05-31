# Development Overview

This repository follows a monorepo layout inspired by full-house.

## Areas

- server: Gleam backend
- client-web: SolidJS frontend
- skir-src: contract definitions
- deploy: deployment and operations helpers

## Delivery Rule

Implement one vertical slice at a time.
A slice is done only when checks are green and the feature works end-to-end.

## Baseline Checks

- Backend: `./scripts/check_backend.sh`
- Frontend: `./scripts/check_frontend.sh`
- Combined: `./scripts/check_all.sh`

## Fast Local Hooks

- Install hooks once: `lefthook install`
- Pre-commit uses `lefthook.yml` with fast checks:
	- `./scripts/check_backend_fast.sh`
	- `./scripts/check_frontend_fast.sh`

Architecture dependency constraints are enforced by the backend lint gate.
