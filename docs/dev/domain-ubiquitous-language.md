# Domain Language and Boundaries

This document defines the MVP bounded contexts and the shared language for each context.

## Bounded Contexts

- Card Catalog
- Collection Import
- Inventory Planning

## Card Catalog

Purpose:
- Maintain enriched card metadata and sync history.

Core terms:
- CatalogCard: normalized card metadata record used by read models and planning.
- CatalogSyncRun: trace record of one manual metadata refresh execution.
- CardIdentity: stable identity tuple for one card.
- CardAttributes: domain attributes needed by catalog and downstream planning.

Boundary notes:
- Owns card metadata language and sync history language.
- Does not own collection quantity semantics.

## Collection Import

Purpose:
- Parse, validate, and persist collection intake runs and resulting snapshots.

Core terms:
- ImportRun: one import execution with source metadata and outcome status.
- CollectionSnapshot: immutable persisted view of imported collection rows for one run.
- ImportSource: source descriptor for the uploaded import file.
- ImportStatus: domain status for an import run lifecycle.

Boundary notes:
- Owns import execution and snapshot semantics.
- Delegates card enrichment language to Card Catalog.

## Inventory Planning

Purpose:
- Represent storage/location rules and produce grouped/sorted inventory projections.

Core terms:
- InventoryRule: user-defined planning rule for location assignment.
- InventoryLocation: destination concept for storage planning.
- InventoryProjection: computed planning output grouped/sorted for execution.
- GroupingStrategy: domain concept describing grouping behavior.

Boundary notes:
- Owns rule and projection semantics.
- Consumes collection and catalog data as inputs through application ports.

## Implementation Anchors

Initial module boundaries are represented by:

- `server/src/domain/contexts.gleam`
- `server/src/domain/card_catalog/context.gleam`
- `server/src/domain/collection_import/context.gleam`
- `server/src/domain/inventory_planning/context.gleam`

## Value Object Foundations

Initial domain-only value objects and invariants:

- Card Catalog
	- `server/src/domain/card_catalog/card_name.gleam`
	- `server/src/domain/card_catalog/set_code.gleam`
- Collection Import
	- `server/src/domain/collection_import/import_source.gleam`
	- `server/src/domain/collection_import/import_status.gleam`
- Inventory Planning
	- `server/src/domain/inventory_planning/location_name.gleam`
	- `server/src/domain/inventory_planning/grouping_strategy.gleam`
