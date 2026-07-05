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
- Parse, validate, and persist the owned collection and the queue of newly-added cards awaiting physical placement.

Core terms:
- Collection: the current owned cards (card key → quantity). The single source of truth other contexts read from.
- UnplacedCards: the sorting queue of additions awaiting physical placement — same shape as Collection. AddCards enqueues here; an import clears it.
- ManualAddition: an incremental, synchronous addition of staged cards (AddCards command). Upserts both the collection and the unplaced queue, summing quantities per key.
- Import: a full statement of the collection (ImportCollection command). Replaces the collection outright and clears the unplaced queue — an import is not placement work.

Boundary notes:
- Owns collection and unplaced-queue semantics.
- Delegates card enrichment language to Card Catalog.

## Inventory Planning

Purpose:
- Represent the physical-sorting scheme as an ordered, copy-consuming rule cascade and project a
  collection through it into per-location pull-lists.

Core terms:
- RuleCascade: the ordered waterfall of rules plus a bulk remainder. Rules apply in `position`
  order and each **consumes** copies from what earlier rules left behind, so one copy is placed
  exactly once.
- InventoryRule / CascadeRule: one waterfall step — a `position`, a copy `selector`, a match
  `predicate`, and a location `target`.
- CopySelector: how many copies of a matching card a rule claims — all copies, the first copy per
  printing, or the first copy per oracle identity.
- Predicate: a rule's match condition — a conjunction (`and`) of set-code / rarity / color-identity /
  type clauses over a card's attributes. A clause referencing an attribute the card lacks is false,
  so the card cascades on.
- LocationTarget: where a rule sends the copies it claims; a fixed name, or a template that fans one
  rule across many locations via a `{set_code}` / `{color_identity}` / `{type}` placeholder.
- BulkSpec: the single leftover-remainder location plus the sort-key list ordering its pile.
- InventoryProjection: the computed placement — locations in cascade order, each with its cards and
  total, plus a count of collection keys unknown to the catalog.
- GroupingStrategy / SortStrategy: legacy planning-preference concepts. They survive **only** for the
  default-sort/grouping preferences; the projection no longer groups or sorts by them.

Boundary notes:
- Owns cascade, rule, and projection semantics.
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
  `(set_code, collector_number)` keys from the target set that appear in the
  collection (exact key match only, no name joins or base-set/variant filtering);
  "total" is the count of distinct collector numbers the catalog has for that set. A target set
  absent from the catalog has `total: 0`.

Boundary notes:
- Owns both sides of target-set tracking: the write side (marking/unmarking a target set) and
  the completion read projection. This is deliberately not Inventory Planning, even though it
  is also preference-shaped — target sets are about collection insight, not storage rules.
- Consumes catalog data (distinct collector numbers per set) and collection data (owned cards)
  as inputs through application ports, the same cross-BC pattern Inventory Planning uses.
