# 0025 — MTGJSON is a second upstream, for the official set size only

- Status: accepted
- Date: 2026-11-14

## Context

Set completion measures owned cards against the set's official size, which is
Scryfall's `printed_size` (52ebbb4). That design assumed a set without
`printed_size` was rare. It isn't: on 2026-11-14, Scryfall `/sets` lacked
`printed_size` for 899 of 1068 sets, including current expansions such as
`eld`, `khm`, `thb` and `war`. The key is absent from the API, and no other
Scryfall surface carries the number: the `is:booster` count disagrees with
the printed size on 7 of 16 checked sets, and `card_count` includes extras
(#113 lists every surface ruled out). v0.5.0 promises that every tracked set
shows ownership against its official set size, and Scryfall alone cannot
deliver that.

MTGJSON's `SetList.json` carries `baseSetSize`, the official set size. It is
MIT-licensed, about 12 MB raw, and dated in a `meta` block. Checked against
live data on 2026-11-14:

- **Set codes match.** MTGJSON codes are Scryfall's codes, uppercased.
  Matching after lowercasing, every non-token Scryfall set except `nac` has an
  MTGJSON entry.
- **It fills most gaps.** Of the 642 paper, non-token sets Scryfall leaves
  unsized, MTGJSON sizes 570, including all four named above. The remaining
  72 are mostly art series (46), minigames (10) and masterpiece sets (6).
- **It disagrees on a few sets Scryfall does size.** The 12 disagreements are
  old, joke or special sets (`8ed`, `9ed`, `ugl`, `unh`, `ust`, `me4`, `j22`,
  `40k`, …), not modern expansions.
- **Some sizes are 0.** `baseSetSize: 0` is MTGJSON's spelling of "unknown".
  It is never a real size. On 2026-11-14, 99 sets had it, all paper: art
  series, minigames, masterpieces, boxed products, and every token set
  MTGJSON lists. All 56 digital sets Scryfall leaves unsized do have an
  MTGJSON size.

A token set has no extras: where Scryfall sizes one, `printed_size` equals
`card_count` (`tstx`: 9 and 9). Of the 219 token sets, 201 have no
`printed_size`. MTGJSON gives none of them a size: it lists only 18 token
sets, all with size 0.

## Considered options

- **Honest labelling only.** Keep Scryfall as the only source and render
  "official size unknown" instead of `owned / —`. This is the smallest
  change, but it breaks the v0.5.0 promise for most expansions.
- **Manual size per target set.** No new upstream, and it covers every set.
  It pushes data entry onto the user for numbers a maintained source already
  publishes. It is not ruled out as a later addition for the sets nothing
  covers.
- **MTGJSON as a fallback source (chosen).** It covers almost every paper,
  non-token set with no user effort. The cost is a second download, a second
  failure mode and a second format to track.
- **MTGJSON as the primary source.** Rejected: Scryfall stays the catalog's
  source of truth (ADR 0008). Where both publish a size, the disagreements
  are on sets where neither is clearly right.

## Decision

The catalog resolves each set's official size **once, at sync**, from these
sources in order:

1. Scryfall `printed_size`, when present.
2. MTGJSON `baseSetSize`, when present and greater than 0, matched on the
   lowercased set code.
3. `card_count`, when the set's Scryfall `set_type` is `token`.
4. Otherwise the size is unknown, and the UI says so.

The resolved size and its source are stored together. Consumers read one
resolved value and never redo the precedence. MTGJSON is used for this one
field only, not as a general second catalog.

MTGJSON is fetched in the catalog's sets import, before the existing sets are
replaced. If the fetch or parse fails, the sets import fails: the refresh is
recorded as failed with the reason, and the previous `catalog_sets` rows stay
in place (ADR 0021). A degraded "imported without fallback sizes" state was
rejected because it needs a new refresh state across the record, the contract
and the UI. Sets only re-import when the Scryfall bulk data changes, so a
short MTGJSON outage delays set updates without corrupting them.

v0.5.0's "every tracked set" promise covers paper sets. A digital-only set
gets a size when an upstream has one, but if it has none, that isn't a gap:
a digital set can't be put in a binder.

## Consequences

- An MTGJSON outage or format change now fails the sets import, even though
  Scryfall is healthy. The refresh error names MTGJSON, so the cause is
  visible.
- MTGJSON's format becomes something to track, at the same level as
  Scryfall's. The parse rejects a present-but-malformed `baseSetSize` loudly
  (ADR 0008), rather than treating it as unknown.
- Each sets import downloads about 12 MB more. The download only happens
  when the Scryfall bulk data has changed.
- 72 paper sets stay unknown: art series, minigames, masterpiece sets such
  as `spg`, `wot` and `otp`, and a few others (`tle`, `tmc`, `rex`, `nau`).
  If they matter, a manual override is the follow-up. This ADR doesn't
  decide that.
- `catalog_sets.printed_size` is replaced by the resolved size and its
  source. The migration clears the sync record so the next refresh re-imports
  the sets.
