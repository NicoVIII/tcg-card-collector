# Domain Language and Boundaries

This document defines the MVP bounded contexts and the shared language for each context.

## Bounded Contexts

- Card Catalog (`server/src/card_catalog/`)
- Collection Import (`server/src/collection/`)
- Inventory Planning (`server/src/inventory_planning/`)
- Insights (`server/src/insights/`)
- Portability (`server/src/portability/`)

## Shared Kernel (`server/src/shared/domain/`)

Value types every context may use: CardKey (the `(set_code, collector_number)`
identity of a printing), CollectorNumber, NonEmptyString, and the
context-independent card facts — Rarity (the enum, no ordering), ColorIdentity
(canonical WUBRG color set), ReleaseDate, OracleId, ManaValue (Scryfall's
`cmc`; "mana value" is the current official term for the same number — the
type keeps that name, the DSL token keeps Scryfall's). CopyKey (`(CardKey, Finish,
Language)`) is the identity of a kind of owned physical copy ([ADR
0010](../decisions/0010-copy-key-finish-and-language.md)); Finish (`nonfoil |
foil | etched`) and Language (Scryfall `lang` codes) are its two closed-set
components, each with no ordering — a total order over either is the
consuming context's policy.

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
  identity, raw type line, release date, mana value), parsed into shared value
  types once at the sync boundary.
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
- Collection: the current owned cards (CopyKey → quantity). The single source of truth other contexts read from. Consumers that care only about the printing (Insights' set completion, Inventory Planning's projection today) add up across CopyKeys and keep working on CardKey (ADR 0010).
- ManualAddition: an incremental, synchronous addition of staged cards (AddCards command). Upserts the collection, summing quantities per CopyKey. A finish or language outside the closed sets rejects the whole batch.
- ManualRemoval: an incremental, synchronous subtraction of staged cards (RemoveCards command) — AddCards' inverse. Decrements the collection per CopyKey, flooring at zero and pruning the row rather than erroring on an over-removal, so correcting a mistyped add doesn't require knowing the exact current count.
- Import: a full statement of the collection (ImportCollection command). Replaces the collection outright, per CopyKey.

Boundary notes:
- Owns collection semantics only. Placement — whether a card is physically sorted — is Inventory Planning's, derived from the collection; Collection holds no placement state. A ManualRemoval or Import that shrinks a key's quantity below what Inventory Planning has already marked placed is announced through the shared event bus (ADR 0011) rather than Collection reaching into Inventory Planning's ledger itself — see that context's boundary notes for the reconciliation policy.
- Delegates card enrichment language to Card Catalog, and — for `ListCollectionCards`' name search only — reads it: a query-only dependency (ADR 0016). Commands never read Card Catalog, so import/add/remove keep working against an empty or unsynced catalog. An owned printing absent from the catalog still matches a set-code filter (part of its own CardKey) but never a name filter.
- Display order for a printing's kinds of copy (finish, then language alphabetically) is Collection's own policy, distinct from Inventory Planning's canonical order over the same CopyKey components.

## Inventory Planning

Purpose:
- Represent the physical-sorting scheme as an ordered, copy-consuming rule cascade and project a
  collection through it into per-location pull-lists.

Core terms:
- PlannedCard: a collection row (one per CopyKey) joined with whatever the catalog knew about it —
  the input the cascade projects. finish and language come from the collection itself and are
  never absent; the catalog-sourced attributes are optional because a collection row may reference
  a printing the catalog doesn't (yet) carry, and such a card fails every attribute predicate and
  cascades to bulk. `supertypes` is `Some([])` for a known card with none, distinct from `None`
  (catalog unknown) — a plain empty list would make a negated supertype clause match a card the
  catalog can't attest to (ADR 0017). `is_token` is the same catalog-gap shape: `None` when the
  catalog has no row or its `layout` hasn't been synced yet (#135's migration forces a reload, but
  the reload itself takes a few minutes), `Some(is_token_layout(layout))` once it has.
- CardAttributes (module): planning's *policy* over the shared card facts — the rarity total
  order (common < uncommon < special < bonus < rare < mythic, so `rarity >= rare` excludes
  special/bonus), the land-first CardType reduction of the raw type line's **front face**, the CR
  205.4a `Supertype` prefix walk over the same front face (a card can carry more than one, e.g.
  "Basic Snow Land"), and the color-identity DSL tokens/labels/sort keys. Type and supertype read
  only the part of the line before `" // "` — outside the game a double-faced card has only its
  front face's characteristics (CR 712.8a, ADR 0018), and a split card's front half is an accepted
  approximation of the whole. The representations themselves live in the shared kernel.
- RuleCascade: the ordered waterfall of rules plus a bulk remainder. Rules apply in `position`
  order and each **consumes** copies from what earlier rules left behind, so one copy is placed
  exactly once.
- InventoryRule / CascadeRule: one waterfall step — a `position`, a copy `selector`, a match
  `predicate`, and a location `target`. Reordering the cascade renumbers every rule's `position`
  contiguously from 0 in one atomic write (`ReorderInventoryRules`) rather than editing one rule's
  position at a time — equal or gapped positions are no longer reachable through the UI.
- CopySelector: how many copies of a matching card a rule claims — all copies, the first copy per
  printing, or the first copy per oracle identity. Both first-copy selectors dedupe on the printing
  or oracle identity, never on CopyKey, so a rule still claims one physical copy total per printing
  regardless of how many kinds of copy (finish/language) it's owned in. *Which* copy it claims is
  the canonical order (ADR 0013): language (`en` first, then by code), then finish
  (`etched > foil > nonfoil`), then release date (oldest first, unknown first), then set code, then
  collector number. Language and finish outrank printing identity, so a first-copy rule claims the
  best copy of a card rather than its oldest printing. This is Inventory Planning's own policy over
  the shared value types, not a property of them, and it is currently fixed (#121 makes it
  configurable). Rule order cannot override it: an earlier rule can route copies to a *different*
  location, but each rule's dedupe set starts empty, so it cannot express a preference within one
  location.
- Predicate: a rule's match condition — a conjunction (`and`) of set-code / rarity / color-identity /
  type / finish / language / supertype / token clauses over a card's attributes. A clause
  referencing a catalog-enrichment attribute the card lacks is false, so the card cascades on;
  finish and language come from the collection itself and are never absent (ADR 0010), so a finish
  or language clause always has a value to match. `set_code`, `color_identity`, `type`, `finish`,
  `language`, and `supertype` also take `!=` (ADR 0017); negation doesn't flip the
  cascade-on-unknown behavior — a negated clause on absent enrichment is still false. Unlike every
  other clause, `supertype = x` / `!= x` is membership, not equality: a card can carry more than
  one supertype, so `= basic` matches if *any* of the card's supertypes is Basic, and `!= basic` is
  true only if *none* of them is. `type` and `supertype` both come from the type line's front face
  only (ADR 0018), so a `Sorcery // Land` MDFC matches `type = sorcery`, never `type = land`.
  `token = yes` / `token = no` (`!=` is accepted and normalizes to the opposite value) matches
  Scryfall's `token`/`double_faced_token` layouts (#135) — the field is reliable where `type`
  isn't, since a token's type line reduces to the same `creature`/`artifact` as a real card. An
  emblem, dungeon, or art-series card (its own distinct layout, e.g. `art_series` for
  `Card // Token Creature — Elemental`) is not a token.
- Set family: a parent set plus all its Scryfall child sets (tokens, promos, art series, … — anything
  linked by `parent_set_code`), resolved transitively to a single family-root set code. The unit a
  `{set_family}` template gathers into one binder.
- LocationTarget: where a rule sends the copies it claims; a fixed name, or a template that fans one
  rule across many locations via a `{set_code}` / `{set_family}` / `{color_identity}` / `{type}`
  placeholder. Fan-out locations are ordered semantically within each rule: `{set_code}` by catalog
  release date ascending (falling back to the card's `released_at` when the set is not yet synced),
  `{set_family}` like `{set_code}` but keyed on the family root's release date/code (so tokens sort
  beside their parent set, not off in their own `tXXX` bucket), `{color_identity}` by mono colors in
  WUBRG order, then multicolor in WOTC's printed order (allied pairs, enemy pairs, shards, wedges,
  four-color, five-color), then colorless last, `{type}` by type rank (land first). Fixed targets sort
  alphabetically. Within a `{set_family}` binder, root-set cards come first and child-set cards after
  ("tokens at the back"), children ordered by their own release date then set code, and the rule's
  sort keys break ties within each group.
- BulkSpec: the single leftover-remainder location plus the sort-key list ordering its pile.
- InventoryProjection: the computed placement — locations in cascade order, each with its cards and
  total, plus a count of collection keys unknown to the catalog.
- PlacedCard: a ledger row recording that some copies of a kind of copy were physically placed in a
  location (`(CopyKey, location) → quantity`). A location holding several kinds of copy of one
  printing needs a tick that names which kind. The write side of placement — MarkCardsPlaced
  adds to it, UnmarkCardsPlaced subtracts, ReconcilePlacedLedger prunes it when Collection
  announces owned quantities may have shrunk (a removal or a re-import), and RelocatePlacedCards
  re-points a whole location's rows onto another location with no CopyKey involved — a bookkeeping
  fix for a rule-target rename, not a record of copies physically moving ([ADR
  0014](../decisions/0014-resort-worklist-is-derived-locations-stay-text.md)) — see boundary notes.
- Placement: one validated MarkCardsPlaced/UnmarkCardsPlaced entry (canonical CopyKey, non-empty
  location, positive quantity).
- Unplaced: **always derived, never stored**, per `(CopyKey, location)` — a projected location's
  quantity minus what's placed there, clamped at zero. Storing it would let a card silently become
  lost; deriving it is self-healing. `PlacementGuidance.total_unplaced` is the sum of this across
  locations, not a second, independent definition computed from the collection total — the two
  disagreeing in the presence of drift was ADR 0014's bug to close. The Place cards page header
  shows a session-adjusted variant of this same sum (`totalToPlace`, `pages/placement_focus.ts`),
  not `total_unplaced` itself: a placement tick deliberately skips refetching the ledger ([ADR
  0015](../decisions/0015-placement-tick-does-not-refetch-the-ledger.md)), so `total_unplaced`
  alone would overcount by whatever the current session already struck until the next page mount.
- Misplaced: **always derived, never stored**, Unplaced's mirror — per `(CopyKey, location)`, what's
  placed there minus what's currently projected there, clamped at zero. Non-zero only where the
  ledger claims a copy sits somewhere the *current* projection no longer sends it (a rule
  re-target, a deleted rule, or a claim-order change moving which copy a rule claims — ADR 0013).
  Not to be confused with #108's AuditFinding (`Missing`/`Unexpected`): Misplaced compares the
  ledger against the *projection*; AuditFinding compares the ledger against *physical reality*.
  Different comparisons, different bugs.
- ResortWorklist: the derived worklist of Misplaced copies (`data/placement/resort.ts`,
  `buildResortWorklist`), grouped by their stale location and paired with the locations where that
  same copy is currently Unplaced — its candidate destinations. A group is flagged as looking like a
  rename only when its whole stale location has vanished from the projection and every misplaced
  copy in it shares exactly one destination — a human-confirmed heuristic, not a claim the system
  can verify, resolved by RelocatePlacedCards; any other shape resolves by pulling copies out
  (UnmarkCardsPlaced) to re-enter PlacementGuidance for their new location ([ADR
  0014](../decisions/0014-resort-worklist-is-derived-locations-stay-text.md)).
- PlacementGuidance: the derived worklist — locations still holding unplaced copies (cascade order,
  empty ones dropped), each card's copies-still-to-place plus its cascade-order neighbours for
  physical orientation, and the grand total of unplaced copies (Unplaced, summed).

Boundary notes:
- Owns cascade, rule, projection, and placement semantics — including how the placed ledger
  self-heals when the collection shrinks. Since Inventory Planning can depend on Collection but
  never the reverse, ReconcilePlacedLedger runs as a subscriber to a shared event bus Collection
  publishes to (ADR 0011) rather than Collection calling into it directly. It re-derives owned
  quantities and the whole ledger on every run (no per-key payload) and, for any key whose placed
  total exceeds what's owned, prunes that key's locations in alphabetical order until it doesn't —
  an arbitrary but deterministic tie-break, since a plain quantity change carries no location to
  blame. ReconcilePlacedLedger has no skir method or REST route; it is only ever invoked as an
  event-bus subscriber.
- Consumes collection and catalog data as inputs through application ports.
- There is no separate Settings context. Target-set preferences for completion tracking belong to
  Insights, not here.

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

## Portability

Purpose:
- Own the single file everything hand-made in the app can leave and re-enter it through —
  its shape, its version, and reading each contributing context's exportable state through
  that context's own facade ([ADR 0019](../decisions/0019-portability-export-format.md)).

Core terms:
- ExportDocument: the whole exported file as this app models it before rendering — a
  format marker, a format_version, the export date, and one section per contributing
  context: `collection`, `insights` (target sets), and `inventory_planning` (rules,
  bulk spec, placed ledger) — #119's full scope.
- format_version: an integer identifying the document's shape, independent of the app's
  own version — it changes only when a section's shape changes in a way an importer must
  branch on, never merely because a new section was added.
- ImportDocument: an ExportDocument's inverse — the valid entries decoded from an
  uploaded file, plus every entry that failed validation, each recorded as a
  RejectedEntry. An import is all-or-nothing at the whole-file level (bad JSON, wrong
  `format`, an unsupported `format_version`, no `collection` array) but per-entry at
  the row level: one bad entry doesn't block the rest.
- RejectedEntry: one entry's section, its position within that section's array, its raw
  identity as given (not yet validated), and why it failed. Position, not a line number:
  JSON carries no line numbers, and a position survives a hand edit's reformatting the
  way a line number wouldn't.
- Section: which part of the document an entry, a rejection, or a written count belongs
  to (`collection`, `insights.target_sets`, `inventory_planning.rules`,
  `inventory_planning.bulk`, `inventory_planning.placed`). A section absent from the
  uploaded file is left untouched on import, not cleared — only `collection` stays
  mandatory. Rules, bulk spec, and the placed ledger replace together in one Inventory
  Planning transaction (one context, ADR 0019's "one place that can check relationships
  between sections"); import writes insights, then inventory_planning, then collection
  last, so a collection-triggered reconciliation (ADR 0011) always runs against the
  other sections' final state.
- LedgerExcess: a placed-ledger key whose total across locations exceeds what the
  document's own collection owns — computed from the document alone, before anything is
  written, so the preview can say what ReconcilePlacedLedger (ADR 0011) will prune right
  after import. Needs no cross-context call: both sides are already Portability's own
  validated data by the time it runs.

Boundary notes:
- Reads and writes every contributing context through that context's `driver/gleam`
  facade, never its internals — the same cross-BC shape Inventory Planning and Insights
  use for Collection and Card Catalog. Each new exportable section costs one more such
  read (and, once import covers it, one more such write).
- Owns the document's own ordering and rendering policy (deterministic entry order, one
  entry per line) — distinct from any consuming context's own display or canonical order
  over the same data. The same module (`driver/export_file.gleam`) both renders and
  parses, so the one file format has one encoder and one decoder.
- Nothing about the document's shape or version is part of the Skir contract — both
  ExportData and ImportData carry the file as opaque text — so a contract change ADR
  0002 allows can never silently break a file already written to disk.
