# 0010 — Owned copies are identified by CopyKey (printing, finish, language)

- Status: accepted
- Date: 2026-09-13

## Context

The collection stores a quantity per CardKey `(set_code, collector_number)`.
But finish (nonfoil / foil / etched) and printed language are part of what is
owned: two German foils and one English nonfoil of `M19/85` are different
physical cards, and sorting schemes treat them differently (a foil binder, a
separate pile for other languages). The deckstats importer reads `is_foil` and
`language` and deliberately drops them, adding up the quantities per CardKey
(#89). A finish rule expression (#71) can't exist until the collection keeps
finish.

The CardKey assumption runs deeper than the Collection. The Inventory Planning
placement ledger (`placed_cards`) records placements per
`(set_code, collector_number, location)`, "unplaced" is calculated per CardKey,
and the cascade's copy pool and first-copy selectors work on CardKey. Adding
finish and language to the collection alone would leave placement unable to
say which copy was placed.

## Considered options

- **Identity of an owned copy**
  - *Quantity per (CardKey, finish, language)* — won. It keeps today's shape of
    interchangeable copies with a count and adds two key columns. A future
    attribute such as condition could join the key the same way.
  - *One row per physical copy* with its own id — lost. Nothing needs to track
    individual copies, and every import and add would turn N copies into N rows.
  - *CardKey quantity plus a separate finish/language breakdown table* — lost.
    Two sources of truth for one quantity.
- **Existing rows**
  - *Backfill `nonfoil` / `en`* — won. The model has no unknown case, and a
    re-import corrects the values.
  - *An explicit `unknown` value* — lost. It would become a permanent member of
    both value sets that every consumer, predicate, and UI must handle, only to
    cover data that gets re-imported anyway.
  - *Wipe the collection and ledger* — lost. It would destroy manual adds and
    placement progress for a concept that still exists.
- **Placement ledger granularity**
  - *Full copy identity* — won. In a location holding several kinds of copy of
    one printing, a tick is only unambiguous if it names the kind.
  - *Stay per CardKey* — lost. Ticks in a shared location are ambiguous, and a
    re-import that corrects finishes keeps ticks for copies that no longer exist.
- **Value sets and type placement**
  - *Closed sets as shared kernel types* — won. Collection and Inventory
    Planning need the same representation, and neither disputes its meaning
    (ADR 0008).
  - *Open language string* — lost. Aliases and typos (`zh` vs `zhs`) would split
    identical copies into separate rows.
  - *Collection-owned types translated at the Inventory Planning port* — lost.
    Duplicate representation with no disagreement about meaning.

## Decision

- **CopyKey** `(CardKey, Finish, Language)` is a shared kernel value type and
  the identity of a kind of owned copy. CardKey keeps meaning *printing*.
- **Finish** is the closed set `nonfoil | foil | etched`. **Language** is the
  closed set of Scryfall `lang` codes (`en, es, fr, de, it, pt, ja, ko, ru, zhs,
  zht, he, la, grc, ar, sa, ph, qya`). Both are shared kernel types, and the
  database enforces them with CHECK constraints on STRICT tables (ADR 0009).
  Orderings over them are the consuming context's policy.
- **Collection** stores a quantity per CopyKey. An import or add row with a
  finish or language outside the set is invalid and rejects the whole request,
  as invalid rows already do. Translating source-specific values (deckstats
  `is_foil`, its language codes) is the client importer's job.
- **The placement ledger** records placements per `(CopyKey, location)`.
  Unplaced is still calculated, never stored, and is now calculated per CopyKey.
- **The cascade** holds its remaining copies per CopyKey. `first_per_printing`
  still dedupes on CardKey and `first_per_oracle` on oracle identity. Among
  kinds of copy of one printing, the canonical order prefers
  `nonfoil < foil < etched`, then `en` before all other languages, then the
  others by code. This preference belongs to Inventory Planning and is changed
  only through rule order, by routing copies with an earlier rule (#71).
- **Consumers that care only about the printing** add up across CopyKeys and
  keep working on CardKey: catalog enrichment joins, set completion.
- **The migration** re-keys `collection` and `placed_cards` and backfills
  every existing row with `nonfoil` / `en`. It destroys no data.

## Consequences

- One identity runs from import through placement. #71 only needs to add a
  predicate clause, with no further model work.
- A breaking contract change, landed atomically (ADR 0002). The collection
  import/add rows, the placement mark/unmark entries, and the rows that
  collection listing, projection, and placement guidance return all gain
  finish and language, with parity on the REST surface (ADR 0004).
- The backfilled values are guesses. Until the collection is re-imported,
  every copy reads as English nonfoil. Placement ticks made before the
  migration are attributed to `nonfoil` / `en`. After a re-import that
  reveals foils or other languages, those copies show as unplaced while the old
  ticks stay on the `nonfoil` / `en` kind, and they need to be re-ticked. The
  release notes must say this.
- Owned finish isn't validated against the finishes the catalog lists for a
  printing. Enrichment may be missing, and the catalog states facts, not
  constraints on what someone may own.
- deckstats can't tell etched from foil, so an etched card imports as foil
  until corrected by hand.
- Adding a Scryfall language, or condition, to the identity needs a migration
  and a contract change. Condition would need its own ADR.
