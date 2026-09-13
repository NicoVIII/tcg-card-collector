# AGENTS.md

## Project Scope

Self-hosted service for managing a Magic: The Gathering collection and planning its physical organization (catalog sync, collection import, location rules → projections). The MVP vertical slice is complete end-to-end. See [docs/vision.md](docs/vision.md) for goals, direction, and non-goals before judging whether a feature or design change is in scope.

## Stack

Gleam backend (Erlang target) + SolidJS/TypeScript frontend, connected by a Skir contract (contract-first RPC with code generation for both sides).

## Code Shape

Readability rules that hold across the stack; each sub-tree's AGENTS.md adds its own specifics.

- **Top-down order**: every definition references only things defined above it — types, then helpers, then the functions that use them, with the entry point (`register`, `main`, the page component) last. Circular references are the only exception.
- **Small, single-purpose functions** are the unit of decomposition. A `// this block does X` comment is the trigger to extract `x()`; skip extraction only when it would thread many parameters or add pure indirection.
- **Comments say why, never what.** If types and names already say it, cut it. Prose is warranted for doc comments on public APIs, type-lossy seams the signature can't express, and short orientation labels in long functions.
- **Repetition is a helper waiting to be named**: the third copy of a pattern extracts a shared function; the first two may stay.
- **A new or tightened rule ships with its migration.** Existing code is brought up to it in the same change, or in dedicated refactoring commits right after — one per rule or cohesive area, each passing `just check` and explaining the rule it applies. A migration too large for that gets an issue and is worked off deliberately, not absorbed "when touched". Lint suppressions are for genuine exceptions with a reason, never for code that merely predates the rule.

## Skeleton First

Names and boundaries are reviewed before bodies exist, because they are cheap to fix in prose and expensive in a diff.

- **A new module, or a change to public types or signatures across more than one module**: first present the skeleton — module paths, types, function signatures, one line of purpose each — and wait for approval before writing bodies. Changes confined to one function's body skip this.
- **An approved or maintainer-written skeleton is fixed.** If a body turns out to need a different type, signature, or module split, stop and say why instead of changing it.

## Development

Task runner is `just` with `::` module scoping (`just --list` for everything). The most-used commands: `just dev` (run backend + frontend), `just check` (all checks), `just skir-gen` (regenerate from contract).

Environment setup for a fresh clone (dbmate, lefthook), repository layout, and the full quality-gate reference live in [docs/dev/development.md](docs/dev/development.md).

Architecture decisions with real alternatives are recorded as ADRs in [docs/decisions/](docs/decisions/README.md). Check there before relitigating a settled design; a changed mind gets a superseding ADR, and a new decision of that weight gets a new record.

Opinionated dual-mode (design-consult + review) aspect skills live in [.claude/skills/](.claude/skills/): `architecture`, `domain-design`, `contract-design`, `data-migrations`, `documentation`, `qa`, and `ux-design`. They encode this project's settled judgement, not generic best practices; consult the relevant one before designing or reviewing in its aspect. The `backlog` skill sits alongside them and owns the work itself: filing issues, grooming the backlog, and release-milestone planning via GitHub issues + milestones.
