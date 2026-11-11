# 0023 — A removal names where its copies were taken from; the alphabetical prune is the fallback

- Status: accepted
- Date: 2026-11-11

## Context

ADR 0011 prunes the placed ledger after the collection shrinks, taking excess
copies from a key's locations in a fixed order (cascade before managed, then
alphabetical), because a quantity change carries no location. That order is
right only by luck. With one copy placed in A and one in B, removing the one
taken from B prunes A: guidance then asks to file a copy into A that is
already there, and the re-sort worklist sends the collector to B for a copy
that is gone (#158, domain story "Copies leave the collection").

The prune also misses the case with no excess at all. Owning two copies, one
placed in A and one loose, and removing the one from A leaves the ledger
claiming A still holds it, and nothing prunes it.

Collection still must not depend on Inventory Planning (ADR 0001), so
`RemoveCards` can't carry a location.

## Considered options

- **A location on `RemoveCards`, passed through the event bus** — lost.
  Collection would carry an Inventory Planning concept on its wire and in its
  event, which is the dependency ADR 0011 exists to avoid.
- **A combined "remove and unplace" command at the composition root** —
  lost. It would be atomic, but it would be the first command that spans
  contexts, adding a transport door and a cross-context transaction just to
  sequence two existing commands.
- **The client unmarks the named location, then removes** — chosen. It needs
  no new command or contract change, and both commands already exist.
- **Ask only when copies are placed in several locations** (the issue's first
  scope) — lost to asking whenever the copy has more than one *source*,
  counting unplaced copies as one. Otherwise the "one placed, one loose" case
  stays wrong.

## Decision

- Removing copies names their **source** per staged line: a location the
  ledger records the copy in, or "unplaced". The remove-cards panel preselects
  the source when there is only one and requires a pick when there are more.
  A deck is a source only for its placed copies beyond what its membership
  claims, since claimed copies can't be removed (ADR 0022).
- On commit the client first unmarks the lines taken from placed locations
  (`UnmarkCardsPlaced`), then calls `RemoveCards`. If the removal fails, it
  marks those copies back. If that compensation also fails, the panel says
  which copies are now counted as unplaced.
- ADR 0011's prune order stays as the **fallback** for paths with no
  per-copy interaction: a portability import that replaces the collection
  without a placed section, and any excess left after a failure between the
  two calls.

## Consequences

- When the collector is asked, the ledger matches what was physically taken.
  The fallback order now runs only on imports, which ADR 0011's naming
  obligation still covers. Listing the rows an import pruned is follow-up
  work.
- The two calls aren't atomic. Unmarking first means the in-between failure
  leaves a copy unplaced, so guidance asks to re-file it, rather than leaving
  a ledger row for a copy that's gone. A crash between the unmark and the
  compensation can still leave a copy unplaced that is physically in place.
  That is visible and fixed by ticking it again.
- Staging now reads the whole placed ledger once per entry. That is the same
  read the placement page already makes.
