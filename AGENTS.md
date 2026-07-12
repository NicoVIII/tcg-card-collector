# AGENTS.md

## Project Scope

Self-hosted service for managing a Magic: The Gathering collection and planning its physical organization (catalog sync, collection import, location rules → projections). The MVP vertical slice is complete end-to-end. See [docs/vision.md](docs/vision.md) for goals, direction, and non-goals before judging whether a feature or design change is in scope.

## Stack

Gleam backend (Erlang target) + SolidJS/TypeScript frontend, connected by a Skir contract (contract-first RPC with code generation for both sides).

## Development

Task runner is `just` with `::` module scoping (`just --list` for everything). The most-used commands: `just dev` (run backend + frontend), `just check` (all checks), `just skir-gen` (regenerate from contract).

Environment setup for a fresh clone (submodules, dbmate, lefthook), repository layout, and the full quality-gate reference live in [docs/dev/development.md](docs/dev/development.md).

Architecture decisions with real alternatives are recorded as ADRs in [docs/decisions/](docs/decisions/README.md). Check there before relitigating a settled design; a changed mind gets a superseding ADR, and a new decision of that weight gets a new record.

Opinionated dual-mode (design-consult + review) aspect skills live in [.claude/skills/](.claude/skills/): `architecture`, `domain-design`, `contract-design`, `data-migrations`, `documentation`, `qa`, and `ux-design`. They encode this project's settled judgement, not generic best practices; consult the relevant one before designing or reviewing in its aspect.
