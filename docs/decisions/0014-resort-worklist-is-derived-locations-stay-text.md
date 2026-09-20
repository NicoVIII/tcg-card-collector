# 0014 — Ledger↔projection drift is derived; locations stay text and a rename re-points records

- Status: accepted
- Date: 2026-09-20

## Context

Three notions of where a copy is, and only two were ever compared: the plan
(`GetInventoryProjection`), the record (`placed_cards`, read via
`GetPlacedLedger`), and reality (nothing observes it — the location audit
workflow, #108). `client-web/src/data/placement/guidance.ts` folded plan
against record, but its two halves used different keys — `buildLocation`
subtracted placed-**at-that-location**, `totalUnplaced` subtracted
placed-**anywhere** — so after a rule re-target the header could read "0
unplaced" while the location lists below still showed cards to place.

This was rare only because rules were effectively immutable (#59); once
editing and reordering a rule became a normal action, a re-target or a
location-target rename routinely strands `placed_cards` rows the projection no
longer targets. ADR 0013's claim-order change produced exactly this drift for
the one real collection this tool manages, and explicitly deferred its
resolution here.

## Considered options

- **Derived worklist vs. tracked re-sort state** — derived won. It matches the
  existing precedent (`Unplaced` is "always derived, never stored... deriving
  it is self-healing" — `docs/dev/domain-ubiquitous-language.md`) and needs no
  new persisted state or invalidation-of-a-cache-of-a-cache problem. Tracking
  a re-sort task list would need its own lifecycle (created, dismissed, gone
  stale when the projection changes again) that the derived fold gets for
  free.
- **Global vs. per-location "unplaced"** — per-location won, which is the fix
  itself: `total_unplaced` is now `Σ` of what the location lists actually
  show, not a second independent definition computed from the collection
  total. The two can no longer disagree, because one is now defined in terms
  of the other.
- **Location identity: stable `(rule_id, rendered fan-out value)` vs. keep
  plain TEXT** — TEXT won, though a stable identity is genuinely constructible
  even under fan-out (a `{set_code}` bucket's identity is `(rule_id,
  set_code)`, resolved from the card's own attributes, not from the location
  name text — a rename of the rule's target string leaves it unchanged). It
  lost on cost, not on principle: re-keying `placed_cards` needs a migration
  that maps every *existing* TEXT row back to the `(rule_id, value)` that
  produced it, and that mapping is the projection itself — rendering
  `{set_family}` requires the catalog's parent-set index, which is Gleam
  application logic, not something a dbmate `.sql` migration can express. It
  also doesn't fully solve the problem: deleting and recreating a rule (or two
  fixed-name rules colliding on one name) still strands rows under stable
  identity, and predicate/claim-order drift (ADR 0013, #121) has nothing to do
  with location identity at all — the worklist is needed either way. Revisit
  if #108 (audit history) or #122 (manual locations) tip the balance.
- **Resolving a likely rename: compose `UnmarkCardsPlaced`+`MarkCardsPlaced`
  client-side vs. a new `RelocatePlacedCards` command** — the new command won.
  Composing two existing calls matches the issue's original "no new placement
  write side" assumption but is non-atomic (a failure between the two calls
  leaves those copies sitting as Unplaced at the new location — recoverable,
  since they simply re-enter the normal pull-list, but not what "just fix the
  record" promised) and ships every row twice over the wire for a location
  holding many copies. `RelocatePlacedCards(from_location, to_location)` is
  one atomic `INSERT...SELECT` + `DELETE` pair and names the act honestly: a
  bookkeeping correction, not a record of cards physically moving.

## Decision

- **Misplaced** is added as `Unplaced`'s mirror: per `(CopyKey, location)`,
  `max(0, placed − projected)`, derived and never stored, clamped at zero.
  `Unplaced` itself changes from a *global* definition (collection quantity
  minus placed quantity per CopyKey) to *per-location* (`buildLocation`'s
  existing clamp), and `PlacementGuidance.total_unplaced` becomes the sum of
  what the location lists show, not an independently-computed number.
- The **re-sort worklist** (`client-web/src/data/placement/resort.ts`,
  `buildResortWorklist`) groups misplaced copies by their stale location and
  pairs each with the locations where that same copy is currently unplaced —
  its candidate destinations. A group is flagged as **looks like a rename**
  only when its whole stale location has vanished from the projection and
  every misplaced copy in it agrees on exactly one destination — the shape a
  plain rename leaves, as opposed to a predicate change that scatters copies
  or strands some with nowhere to go. This is a heuristic a human confirms,
  never a fact the system asserts: the same shape also results from deleting
  a location and adding a coincidentally-single-destination rule elsewhere.
- **Locations remain plain TEXT**, exactly as `placed_cards.location` already
  is. No location identity, stable or otherwise, is introduced by this
  change.
- **`RelocatePlacedCards(from_location, to_location)`** (new command, skir
  method 310) re-points every row at one location onto another in a single
  atomic write (`placed_cards_dao.relocate`), merging into any row already at
  the destination the same way `increment` does. It carries no `CopyKey` —
  it operates on a location's rows as a whole, which is exactly the set a
  "looks like a rename" group's from-location has, by construction.
- `location_target.parse` now trims its input, the same canonicalization
  `placement.new` already applies to a placed location. An untrimmed rule
  target previously rendered a projected location the ledger's trimmed keys
  could never match — permanent drift no worklist action could clear, since
  the "destination" differed from the "source" by whitespace alone.

## Consequences

- The unplaced total and the per-location lists can no longer disagree — the
  bug this issue exists to close.
- A rule re-target or predicate change that strands placed copies is now
  visible (the Re-sort section on `/placement`) and actionable (pull the copy
  out to re-file it, or confirm the record-only fix for a likely rename)
  instead of silently invisible, which is what happened before: a copy placed
  at a location no longer in the projection appeared in no location's list at
  all, to-place or otherwise.
- #108's location-audit workflow inherits both calls made here as settled:
  audit history keys on the same TEXT `location`, exactly as `placed_cards`
  does, and a location rename orphans audit history the same way it orphans
  placed rows — #108 does not need to solve that again. Likewise #122 (manual
  locations) adds to this same plain-TEXT space rather than to a typed
  identity.
- `RelocatePlacedCards` has no `CopyKey`, unlike every other placement command
  — it is the first placement write that isn't itemized per copy. A caller
  that wants to relocate only *some* of a location's rows must still use
  `UnmarkCardsPlaced` + `MarkCardsPlaced` for those; this command is only ever
  offered by the UI when the whole location's drift maps to one destination.
- A rename detected by the heuristic and confirmed by "Update record only"
  that turns out to be wrong (two different physical things coincidentally
  landed on one destination) merges their ledger rows under the same
  location with no record of the mistake — the same trust already placed in
  `MarkCardsPlaced`'s summing behavior, extended to a bulk operation.
- Trimming rule targets on parse is a silent, self-healing behavior change:
  an existing rule with a padded target starts producing a different
  (trimmed) projected location name on the next read, with no migration and
  no user action, since rules are stored as raw text and re-parsed every
  time.
