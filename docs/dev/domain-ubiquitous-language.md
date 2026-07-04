# Domain Language and Boundaries

This document defines the MVP bounded contexts and the shared language for each context.

## Bounded Contexts

- Card Catalog (`server/src/catalog/`)
- Collection Import (`server/src/collection/`)
- Inventory Planning (`server/src/inventory_planning/`)
- Insights (`server/src/insights/`)

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
- Also owns *planning* preferences (default sort/grouping) — there is no separate Settings
  context. Target-set preferences for completion tracking belong to Insights, not here.

## Insights

Purpose:
- Surface derived, cross-context views over the collection — starting with set completion
  tracking. The future home of the vision's broader "collection insights" theme.

Core terms:
- TargetSet: a set (by set code) the user has marked as one they want to track completion for.
- SetCompletion: the owned/total pair for one target set — "owned" is the count of distinct
  `(set_code, collector_number)` keys from the target set that appear in the latest succeeded
  collection snapshot (exact key match only, no name joins or base-set/variant filtering);
  "total" is the count of distinct collector numbers the catalog has for that set. A target set
  absent from the catalog has `total: 0`.

Boundary notes:
- Owns both sides of target-set tracking: the write side (marking/unmarking a target set) and
  the completion read projection. This is deliberately not Inventory Planning, even though it
  is also preference-shaped — target sets are about collection insight, not storage rules.
- Consumes catalog data (distinct collector numbers per set) and collection data (owned cards)
  as inputs through application ports, the same cross-BC pattern Inventory Planning uses.
