# 0006 — Placement guidance is derived client-side from projection + placed ledger

- Status: accepted
- Date: 2026-07-09

## Context

The Place Cards page shows, per location, the cards still to be filed and where
each one goes. This "guidance" is the inventory projection minus the placed
ledger: for each projected card, how many copies are not yet marked placed here,
plus its cascade neighbours.

Originally a single `GetPlacementGuidance` RPC composed both server-side.
Ticking a card marked it placed and invalidated the guidance query, so the page
refetched — and each refetch recomputed the **entire projection** (full
collection read + catalog batch-load + set release dates + rule-cascade
projection), paid O(collection) on every checkbox click. But a placement tick
changes only the placed ledger; the projection is derived from collection,
rules, and catalog, none of which the tick touches. The expensive recompute was
pure waste, and it grew with collection size — the reported slowness.

The two inputs have very different change rates: the projection changes rarely
(collection import, rule/bulk edit, catalog refresh); the ledger changes on
every tick but is cheap to read.

## Considered options

- **Server-side projection cache** — keep the single guidance endpoint, memoize
  the projection in an ETS/actor cache keyed by a collection+rules version.
  Keeps all domain logic server-side, but needs greenfield cache infrastructure
  and cross-context invalidation (a collection import or catalog refresh in
  another bounded context must bust inventory_planning's cache), which the
  strict context-isolation rules make awkward.
- **Purpose-built placement-skeleton RPC** — a new server endpoint returning the
  neighbour-windowed skeleton without the ledger-dependent bits, folded with a
  cheap ledger read on the client. Keeps neighbour ordering server-side but adds
  a bespoke cacheable shape distinct from the projection the inventory page
  already consumes.
- **Client-side merge, reuse the existing projection RPC** — the page consumes
  the already-cached `GetInventoryProjection` plus a new cheap `GetPlacedLedger`
  and folds them into guidance in the browser. No new server shape, no cache
  infrastructure; the projection stays cached across ticks via TanStack Query.
  Cost: a slice of placement logic (to-place clamp, ±2 neighbour windowing,
  already-placed flags, total-unplaced) moves to the client, and the
  server-side guidance tests go with it.

## Decision

Guidance is built on the client. The placement page reads the cached
`GetInventoryProjection` and a new `GetPlacedLedger` RPC and folds them in
`client-web/src/data/placement/guidance.ts` (`buildGuidance`). A tick
invalidates only the placed-ledger query; the projection is refetched only when
something that actually feeds it changes. The server-side `placement_guidance`
use case is retired.

Because the projection now backs the placement page (not just the inventory
page), every mutation that changes it must invalidate `inventoryProjection`:
collection add/import and — newly — a completed catalog refresh (which also
busts `setCompletion`). The old per-tick recompute had masked those gaps.

## Consequences

- A placement tick costs a small ledger read plus an in-memory fold instead of a
  full projection recompute; the work no longer scales with collection size.
- The projection is computed once per real change rather than once per click,
  shared between the inventory and placement pages through one cache entry.
- Placement's to-place/neighbour/total-unplaced logic now lives on the client
  (`data/placement/guidance.ts`, vitest-covered) rather than in a Gleam handler.
  Two implementations of that logic no longer exist; the client one is
  authoritative. If a non-browser consumer ever needs guidance, it must either
  re-derive the fold or this ADR is superseded by a server-composed endpoint.
- Cache correctness now depends on invalidating `inventoryProjection` from every
  writer that affects it, across bounded contexts. That obligation is explicit
  and easy to overlook — a new projection input needs a matching invalidation.
- `GetPlacedLedger` reuses the retired method's contract slot (306) with the old
  response fields tombstoned, per [0002](0002-unversioned-contract-atomic-breaking-changes.md).
