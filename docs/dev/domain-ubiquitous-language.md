# Domain Language and Boundaries

This document defines the MVP bounded contexts and the shared language for each context.

## Bounded Contexts

- Card Catalog (`server/src/card_catalog/`)
- Collection Import (`server/src/collection/`)
- Inventory Planning (`server/src/inventory_planning/`)
- Insights (`server/src/insights/`)

## Shared Kernel (`server/src/shared/domain/`)

Value types every context may use: CardKey (the `(set_code, collector_number)`
identity of a printing), CollectorNumber, NonEmptyString, and the
context-independent card facts — Rarity (the enum, no ordering), ColorIdentity
(canonical WUBRG color set), ReleaseDate, OracleId.

A type qualifies here when more than one context needs the same
*representation* and no context disputes its semantics. Policy never moves in
with it: orderings, labels, reductions, and DSL concerns stay in the context
that owns them ([ADR 0008](../decisions/0008-shared-value-types-parse-at-sync-boundary.md)).

## Card Catalog

Purpose:
- Maintain enriched card metadata and sync history.

Core terms:
- CardPrinting: one printed card as the source of truth knows it — identity
  (CardKey), name, image, and the enrichment facts (rarity, oracle id, color
  identity, raw type line, release date), parsed into shared value types once
  at the sync boundary.
- CardSet: one set's metadata — code, name, release date, card count, official
  printed size, icon, and the parent-set link that chains a set family.
- ProbeResult / RefreshRecord: trace of the last refresh probe — when, which
  upstream version, and whether it succeeded, was skipped, or failed.

Boundary notes:
- Owns card metadata language and sync history language. Enrichment facts are
  stored and served verbatim, never interpreted — any reduction over them
  (orderings, type-line categorization) is consumer policy. That is why the
  raw type line, not a card type, is the catalog fact.
- Does not own collection quantity semantics.

## Collection Import

Purpose:
- Parse, validate, and persist the owned collection.

Core terms:
- Collection: the current owned cards (card key → quantity). The single source of truth other contexts read from.
- ManualAddition: an incremental, synchronous addition of staged cards (AddCards command). Upserts the collection, summing quantities per key.
- Import: a full statement of the collection (ImportCollection command). Replaces the collection outright.

Boundary notes:
- Owns collection semantics only. Placement — whether a card is physically sorted — is Inventory Planning's, derived from the collection; Collection holds no placement state.
- Delegates card enrichment language to Card Catalog.

## Inventory Planning

Purpose:
- Represent the physical-sorting scheme as an ordered, copy-consuming rule cascade and project a
  collection through it into per-location pull-lists.

Core terms:
- PlannedCard: a collection row joined with whatever the catalog knew about it — the input the
  cascade projects. Attributes are optional because a collection row may reference a printing
  the catalog doesn't (yet) carry; such a card fails every attribute predicate and cascades to
  bulk.
- CardAttributes (module): planning's *policy* over the shared card facts — the rarity total
  order (common < uncommon < special < bonus < rare < mythic, so `rarity >= rare` excludes
  special/bonus), the land-first CardType reduction of the raw type line, and the color-identity
  DSL tokens/labels/sort keys. The representations themselves live in the shared kernel.
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
- Set family: a parent set plus all its Scryfall child sets (tokens, promos, art series, … — anything
  linked by `parent_set_code`), resolved transitively to a single family-root set code. The unit a
  `{set_family}` template gathers into one binder.
- LocationTarget: where a rule sends the copies it claims; a fixed name, or a template that fans one
  rule across many locations via a `{set_code}` / `{set_family}` / `{color_identity}` / `{type}`
  placeholder. Fan-out locations are ordered semantically within each rule: `{set_code}` by catalog
  release date ascending (falling back to the card's `released_at` when the set is not yet synced),
  `{set_family}` like `{set_code}` but keyed on the family root's release date/code (so tokens sort
  beside their parent set, not off in their own `tXXX` bucket), `{color_identity}` by
  WUBRG → multicolor → colorless, `{type}` by type rank (land first). Fixed targets sort
  alphabetically. Within a `{set_family}` binder, root-set cards come first and child-set cards after
  ("tokens at the back"), children ordered by their own release date then set code, and the rule's
  sort keys break ties within each group.
- BulkSpec: the single leftover-remainder location plus the sort-key list ordering its pile.
- InventoryProjection: the computed placement — locations in cascade order, each with its cards and
  total, plus a count of collection keys unknown to the catalog.
- PlacedCard: a ledger row recording that some copies of a key were physically placed in a location
  (`(set_code, collector_number, location) → quantity`). The write side of placement — MarkCardsPlaced
  adds to it, UnmarkCardsPlaced subtracts.
- Placement: one validated MarkCardsPlaced/UnmarkCardsPlaced entry (canonical key, non-empty location,
  positive quantity).
- Unplaced: **always derived, never stored** — collection quantity minus placed quantity per key,
  clamped at zero. Storing it would let a card silently become lost; deriving it is self-healing.
- PlacementGuidance: the derived worklist — locations still holding unplaced copies (cascade order,
  empty ones dropped), each card's copies-still-to-place plus its cascade-order neighbours for
  physical orientation, and the grand total of unplaced copies.
- GroupingStrategy / SortStrategy: legacy planning-preference concepts. They survive **only** for the
  default-sort/grouping preferences; the projection no longer groups or sorts by them.

Boundary notes:
- Owns cascade, rule, projection, and placement semantics.
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
