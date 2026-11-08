# 0022 — Managed locations: consumed before the cascade, membership is intent, locations get two namespaces

- Status: accepted
- Date: 2026-11-08

## Context

A card sitting in a constructed deck is still owned but not in the binder.
Until #122 the only way to keep the projection honest about that was to remove
the card from the collection, which loses the fact that it's owned. The
projection had exactly one way to route a copy — the rule cascade, which
claims copies by matching attributes — and no way to say "this named copy is
over there".

Decks are the first case, but not the only plausible one: a trade box or a
display case is the same shape (a named place whose contents are a list, not
a predicate). The vision's Deck building non-goal still stands; a deck here is
a storage destination only.

## Considered options

- **Where the concept lives** — a module inside Inventory Planning won over a
  new bounded context. It answers that context's question (where does this
  copy physically go?), and admitting it gives no word a second meaning there.
- **Precedence** — a fixed "managed locations first" rule won over giving
  each managed location a cascade position. The intent is "this copy is in the
  deck, full stop"; a position would buy the ability to let a rule outrank a
  deck, which nobody has asked for, at the cost of a second ordering concept.
- **Reuse the placed ledger** — lost. The ledger records what has been
  physically sorted (a fact); deck membership says where a copy should be
  (intent). Overloading one table with both would make Unplaced/Misplaced
  meaningless for decks.
- **What happens when the collection shrinks below a deck's membership** —
  a derived *shortfall* won over pruning membership through the event bus
  (ADR 0011's pattern for the ledger). Membership is a wish that outlives the
  copy: pruning it would silently empty a deck slot the user wants back once
  the card is re-acquired. The ledger keeps pruning, because it records fact,
  not intent. Write-side rejection of the shrink itself lost: Collection can't
  ask Inventory Planning (ADR 0011's dependency direction), and an import
  can't be partially refused. The client warns instead (it guards removals,
  and the import preview lists shortfalls).
- **Location identity** — two namespaces won over keeping every location as
  text (ADR 0014). With text, a deck named like a rule target silently merges
  with it in both the projection and the ledger, and renaming a deck would
  strand its ledger rows. A rule target's rendered name can't be checked for
  collisions up front either, since `{set_code}`-style templates render at
  projection time.

## Decision

- A **ManagedLocation** is a named location in Inventory Planning whose
  contents are an explicit membership list of `(CopyKey, quantity)` rows.
  `Deck` is its only kind for now.
- The projection consumes every managed location's copies from the pool
  **before** any cascade rule sees it. A copy a managed location holds never
  reaches a rule location or bulk.
- Adding to a managed location beyond what's owned (minus what other managed
  locations already hold) is rejected as a bad request (ADR 0021).
- When the collection holds fewer copies than all managed locations claim,
  the projection shows the gap as a per-location **shortfall**, derived and
  never stored. Membership is not pruned. When several managed locations
  compete for the same scarce copy, the one whose name sorts first gets it.
- A location is a `LocationRef`: `cascade(name)` for rule targets and bulk —
  still ADR 0014's text — or `managed(id)`. The placed ledger, the
  projection, and the wire all carry the kind. Renaming a managed location
  never touches the ledger; deleting one removes its ledger rows in the same
  transaction, so its copies re-enter placement guidance at their cascade
  destination.

## Consequences

- ADR 0014 still holds for cascade locations — rule-target renames still go
  through RelocatePlacedCards — but it no longer describes every location.
- Every client fold that keyed on a location name (placement guidance, the
  re-sort worklist, the placement session, `?location=`) keys on a
  `locationKey` string now, and carries the display name separately.
- `placed_cards` gained a `location_kind` column (migration 0021). Its
  `managed` rows have no foreign key: the column is polymorphic, and the
  app's connections don't enable foreign keys anyway.
- A second managed-location kind is a new enum value plus whatever is
  specific to it; precedence, shortfall, and the namespace come for free.
- Shortfall tie-breaking by name is arbitrary. It's acceptable only because a
  shortfall is always visible; if users hit it often, a deck-level priority
  is the natural next step.
