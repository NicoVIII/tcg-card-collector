# AGENTS.md

## Project Scope

Self-hosted service for managing a Magic: The Gathering collection and planning its physical organization (catalog sync, collection import, location rules → projections). The MVP vertical slice is complete end-to-end. See [docs/vision.md](docs/vision.md) for goals, direction, and non-goals before judging whether a feature or design change is in scope.

## Stack

Gleam backend (Erlang target) + SolidJS/TypeScript frontend, connected by a Skir contract (contract-first RPC with code generation for both sides).

## Development

Task runner is `just` with `::` module scoping (`just --list` for everything). The most-used commands: `just dev` (run backend + frontend), `just check` (all checks), `just skir-gen` (regenerate from contract).

Environment setup for a fresh clone (submodules, dbmate, lefthook), repository layout, and the full quality-gate reference live in [docs/dev/development.md](docs/dev/development.md).
