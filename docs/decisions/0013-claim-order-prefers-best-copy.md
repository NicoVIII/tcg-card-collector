# 0013 — First-copy rules claim the best copy, not the oldest printing

- Status: accepted
- Date: 2026-09-20

## Context

ADR 0010 gave Inventory Planning a canonical order over owned copies, and the
cascade's first-copy selectors walk it to decide which physical copy a rule
claims: release date (oldest first, unknown first), then set code, then
collector number, then finish (`nonfoil < foil < etched`), then language (`en`
first, then by code). It reads as "prefer the oldest printing", with finish and
language only separating kinds of copy of one printing.

The collection this tool was built for was physically sorted, years before the
tool existed, under a different policy: English first, then
`etched > foil > nonfoil`, then release date, then collector number — "the
nicest copy of each card goes in the binder". The projection therefore
disagrees with the shelf, and driving how an actual collection is physically
sorted is the tool's first stated purpose (`docs/vision.md`).

ADR 0010 also claimed the preference "is changed only through rule order, by
routing copies with an earlier rule". That is wrong, and its wrongness is what
turns this into a decision rather than a configuration exercise.
`rule_cascade.apply_rule` builds a fresh `claimed` set per rule, so an earlier
`finish in (etched)` rule pointed at the same location does not *prefer* the
etched copy: the later rule starts with an empty claimed set and takes another
copy of the same card, putting two in the binder. Rule order can route copies
to a *different* location; it cannot express a preference within one. There is
no workaround to wait behind.

The order was also effectively untested. One cascade-level test covered it, and
it varied finish and language together (nonfoil-en vs foil-de), so it passed
under orderings that rank those two steps very differently. A test per step
landed first (commit a33db00) so this change is visible as failures rather than
as silence.

## Considered options

- **Order**
  - *Adopt the collection's own order as the fixed default* — won. It is the
    only option that makes today's projection agree with today's shelf, and
    the cost of being wrong is bounded: one user, no released version, and the
    sorting it describes has already happened.
  - *Keep ADR 0010's order until #121 makes it configurable* — lost. It leaves
    the single real collection mis-projected for the whole wait, and with rule
    order ruled out there is nothing to bridge the gap.
  - *Jump straight to a configurable preference (#121)* — lost for now, not
    rejected. It is several times the work (domain value, persistence,
    contract, UI) for one user who wants one order, and it still has to pick a
    default — which is this decision either way.
- **Unknown release dates** (`released_at` is catalog enrichment and can be
  absent)
  - *Keep sorting them first* — won. `compare_release_earliest_first` also
    orders set and family *buckets*; changing it would move bucket ordering
    too, so unknown-last would mean a second release-date comparator in the
    same module. The case is rare (Scryfall dates effectively everything, so
    absence means the catalog is missing that printing) and self-correcting on
    the next refresh.
  - *Sort them last, like every other optional attribute* — lost on that cost,
    not on principle. Revisit if unknown-dated copies are observed winning
    binder slots.
- **Deterministic tail**
  - *`set_code` before `collector_number`* — won. Collector numbers are not
    unique across sets, so without it two copies can compare equal and the
    projection stops being stable between runs.
  - *Collector number alone, as stated from memory* — lost for that reason.

## Decision

- The canonical order that first-copy selectors claim by is, in full:
  **language (`en` first, then by Scryfall code) → finish
  (`etched > foil > nonfoil`) → release date (oldest first, unknown first) →
  set code → collector number.**
- Language and finish now outrank printing identity, so the selectors mean
  "the best copy of each card", not "the oldest printing of each card".
- This order is Inventory Planning's policy over shared kernel value types
  (ADR 0008), exactly as ADR 0010's was. It is not a claim about what any
  collection *should* prefer.
- It stays the only order until #121 makes it configurable, at which point it
  becomes that feature's default rather than a constant.
- Every step is covered by a test that fails if that step is reordered. A
  change to the order that breaks no test means the test is missing, not that
  the change is safe.

## Consequences

- The projection matches a collection already sorted this way. Nothing has to
  be re-sorted to adopt it.
- A personal preference is now the project default, and the project intends to
  be self-hostable by others. A second user inherits "nicest copy in the
  binder" without asking for it. This is deliberate and bounded by #121; it is
  a reason to land #121 before the project has a second user, not a reason to
  keep an order that fits nobody.
- Placement ticks recorded under ADR 0010's order can now point at copies a
  rule no longer claims: the copy shows placed while the newly claimed one
  shows unplaced. This is the same class as #107 (rule changes stranding
  placed copies) and is left to it. In this collection's case the drift runs
  *towards* the shelf, not away from it.
- `first_per_printing` changes too, not only `first_per_oracle`: within one
  printing the claimed copy flips from nonfoil to etched where both are owned.
- Canonical order doubles as the display fallback for a rule with no sort keys
  (`sort_spec.compare_cards([])` is `Eq`, so the sorted input order shows
  through). Such a location now lists English before other languages and etched
  before nonfoil, where it previously listed oldest printing first. Splitting
  claim order from display fallback would mean a second comparator threaded
  through `project` for a degenerate case; a rule that wants a different layout
  states sort keys, which is what they are for.
- The two orders in `rule_cascade` now differ in spirit — copies are claimed
  best-first, while buckets are still ordered oldest-set-first. That is
  intended (a binder's *contents* are still laid out chronologically) but it is
  no longer self-evident from the module, so both comparators say which job
  they do.
- ADR 0010 keeps everything else it decided: CopyKey identity, the closed value
  sets, the ledger granularity, the migration. Only its canonical-order
  paragraph and its rule-order escape hatch are superseded here.
