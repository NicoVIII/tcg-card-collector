# tcg-card-collector

[![Last commit](https://img.shields.io/github/last-commit/NicoVIII/tcg-card-collector?style=flat-square)](https://github.com/NicoVIII/tcg-card-collector/commits/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](LICENSE)

A self-hosted service for managing a Magic: The Gathering card collection and planning its physical organization. Card metadata is synced from Scryfall, the owned collection is imported from CSV exports, and user-defined location rules turn the collection into grouped and sorted projections — a plan for sorting real cards into real storage.

See [docs/vision.md](docs/vision.md) for why the project exists, where it is heading, and what it deliberately will not do.

## What works today

- Catalog sync from Scryfall
- CSV collection import with immutable snapshots
- Location rules and inventory projections for physical sorting
- Planning preferences
- All of it available over Skir RPC and REST

## Status

The MVP vertical slice works end-to-end, but there is no packaged release yet — running it means running from source ([development guide](docs/dev/development.md)). The deployment model is a single user on a trusted network: the app has **no authentication**.

## Architecture

Gleam backend (Erlang target) and SolidJS/TypeScript frontend, connected by a [Skir](https://github.com/gepheum/skir) contract — contract-first RPC with code generation for both sides. The backend follows hexagonal architecture with DDD bounded contexts, and the boundaries are lint-enforced. This rigor is deliberate: the project doubles as an architecture playground, not just a tool.

## Development

Setup, commands, and quality gates are documented in the [development guide](docs/dev/development.md).
