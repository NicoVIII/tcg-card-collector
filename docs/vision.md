# Vision

This document states why the project exists, where it is heading, and what it deliberately will not do. Use it to judge whether a feature idea or design change is in scope.

## What is this?

A self-hosted service for managing a Magic: The Gathering card collection and planning its physical organization. Card metadata is synced from Scryfall into a catalog, the owned collection is imported from CSV exports, and user-defined location rules turn the collection into grouped/sorted projections for sorting real cards into real storage.

## Why it exists

Three purposes, all first-class:

1. **A real personal tool.** It manages an actual collection and drives how it is physically sorted. Features are grounded in that concrete need.
2. **An architecture playground.** The rigor — hexagonal architecture, DDD bounded contexts, CQRS, contract-first RPC, lint-enforced boundaries — is a goal in itself, not incidental overhead.
3. **An open-source product.** Others should eventually be able to self-host it, so documentation, packaging, and honest scope statements matter beyond personal use.

## Current status

The MVP vertical slice works end-to-end: catalog sync from Scryfall, CSV collection import with immutable snapshots, inventory rules and projections, and planning preferences — over both Skir RPC and REST.

## Direction

Themes, deliberately unordered — this is not a committed sequence:

- **Deepen inventory planning.** Richer rule expressions and better projections; the physical-sorting workflow is the differentiator.
- **Set-completion tracking.** Mark specific sets as collection targets and get an overview of collection state against them.
- **Import pipeline breadth.** More sources and formats, and incremental imports/diffs instead of full snapshots only.
- **Collection insights.** Search and filtering across the collection, statistics, pricing/value via Scryfall data.
- **Packaging & deployment.** Make `container/` real: a published image, a release process, and an upgrade/migration story.

The deployment model today is a single user on a trusted network; the app has no authentication. Multi-user support is a real future direction and a known architectural commitment — flagged here so it isn't designed against, but not built yet.

## Someday, maybe (not designed for)

Acknowledged as possible futures, but no current design bends to accommodate them:

- Support for other TCGs (Pokémon, Yu-Gi-Oh, …) — Magic is the scope for the foreseeable future.
- Card scanning/recognition — imports come from files produced by tools that already do this.
- Native mobile apps — the web UI is the interface.

## Non-goals

- **Deck building.** No deck construction, legality checking, or playtesting — Moxfield and friends do this well already. This is a collection and inventory tool.
- **Trading & marketplace.** No trade matching, shared want-lists, buying/selling, or price alerts.
