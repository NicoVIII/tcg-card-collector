# 0015 — A placement tick marks the ledger stale but does not refetch it

- Status: accepted
- Date: 2026-09-20

## Context

Ticking a placement checkbox was noticeably laggy on a realistic collection
(#105), for two compounding reasons:

1. `mergeLocationCards` (`client-web/src/pages/placement_session.ts`) built a
   fresh `{ card, struck }` wrapper object for every card on every call.
   Solid's `<For>` keys by reference, so a tick disposed and recreated every
   `<li>` in the open location instead of patching the one that changed.
2. `markMutation`/`unmarkMutation` invalidated `queryKeys.placedLedger()` on
   success, triggering a full ledger read (`placed_cards_dao.list()`, a
   growing full-table scan) followed by a full re-derivation: `buildGuidance`
   **and** `buildResortWorklist` (ADR 0014) both refold the whole projection
   on the placement page, and again in `components/placement_work_badge.tsx`
   — four O(collection) folds per click — producing fresh `PlacementCard`
   objects that triggered a second full row rebuild.

The row-identity problem (1) is fixed by having `mergeLocationCards` return
guidance's own `PlacementCard` objects (not copies) and moving `struck` out of
the row shape entirely — it's asked of the session signal per row
(`isTicked`) rather than carried as row state. That alone stops the rebuild
`<For>` triggers, but it only pays off if the array it renders stays
reference-stable across a tick — which it won't if a tick keeps refetching the
ledger and re-deriving a fresh `PlacementCard[]` on the far side of that
refetch. The refetch itself (2) had to go too.

## Considered options

- **Keep invalidating (status quo)** — simplest, but reintroduces exactly the
  refetch-then-refold cost this issue exists to remove; the row-identity fix
  alone would only mask the DOM cost, not the network + fold cost.
- **Optimistic `setQueryData` on the ledger cache** — apply the tick to the
  cached ledger rows directly instead of invalidating, so the cache and the
  session agree without a round trip. Keeps the ledger live for every reader
  (the nav badge included) but means `buildGuidance`/`buildResortWorklist`
  still refold the whole projection on every tick — the same O(collection)
  cost this issue is about, just without the network leg. It also duplicates
  the tick's effect in two places (the session and the ledger cache), which
  is exactly the kind of drift ADR 0014 exists to warn about.
- **Mark stale, refetch only on next mount (chosen)** — the placement page
  already treats the session as display truth for anything ticked this
  session (`placement_session.ts`, `placement_focus.ts`); the ledger query
  only exists to seed and reconcile that session. A tick invalidates the
  ledger query with `refetchType: "none"` (stale, not refetched) instead of
  awaiting a refetch. Nothing on the placement page reads the ledger directly
  mid-session — everything goes through `session()` — so no fold happens
  until something actually remounts the query.

## Decision

`useMarkCardsPlacedMutation` and `useUnmarkCardsPlacedMutation` mark
`queryKeys.placedLedger()` stale without refetching it
(`invalidateQueries({ refetchType: "none" })`). The placed-ledger query also
drops `refetchOnWindowFocus`, since every tick already marks it stale for the
rest of the session — refetching on focus would pay the same full refold and
row rebuild on every alt-tab back to the page. `useRelocatePlacedCardsMutation`
is unaffected: a relocation is rare, not part of the per-tick hot path, and the
re-sort worklist it resolves needs to reconcile against real ledger rows
immediately.

The session (`PlacementSession`) is authoritative for what this browser tab
has ticked until the ledger query next mounts (a page navigation or reload).
`betweenLabel`'s cascade-neighbour anchor is widened to agree with this: a
neighbour reads as placed when the ledger says so *or* the session ticked it
(`placement_session.ts`'s `placedAnchorLabel`), so the very next card's hint
doesn't regress to the weaker "still to place" phrasing the moment the card
before it is ticked.

## Consequences

- A tick costs one client-side state update and a per-row `isTicked` lookup —
  no network call, no projection refold, no ledger read — instead of a full
  ledger fetch plus two O(collection) folds.
- `components/placement_work_badge.tsx`, which folds the same ledger query,
  freezes at its pre-session count for the duration of an active sorting
  session and catches up on the next mount. Live-updating it would mean
  writing the ledger cache per tick (the rejected optimistic-`setQueryData`
  option), which reintroduces the O(collection) refold this decision removes.
- The ledger no longer self-heals via window-focus refetch mid-session. A
  second tab or device placing cards against the same collection will not be
  reflected here until the page remounts; this app is self-hosted and
  single-user by design (see [docs/vision.md](../vision.md)), so concurrent
  writers were already an edge case, not a supported scenario.
- `PlacementGuidance.total_unplaced` (the fold's own definition, unaffected by
  this ADR) is no longer what the page header shows while a session is active;
  the header shows `totalToPlace` (`pages/placement_focus.ts`), the same sum
  session-adjusted. A reader of `domain-ubiquitous-language.md` needs that
  distinction spelled out, not just implied by the code.
