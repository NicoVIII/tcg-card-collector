# 0024 — A location audit is applied in one atomic command at completion

- Status: accepted
- Date: 2026-11-11

## Context

The placed ledger is the system's belief about where copies physically are,
and nothing checked it against reality (#108). An audit walks one location
and yields three kinds of finding: copies recorded but not found (Missing),
copies found that the ledger doesn't record there (Unexpected), and the rest
(Confirmed). A copy is only known to be missing once the whole location has
been looked at, so the Missing half can't be applied before the walk ends.

The issue first assumed "no new placement write side": compose
`UnmarkCardsPlaced` and `MarkCardsPlaced` from the client and apply each
unexpected find as it is entered. Two things broke that assumption.
`MarkCardsPlaced` doesn't cap at the owned quantity, so marking a misfiled
copy at the audited location leaves the ledger claiming more placed copies
than are owned. And a history of completed audits is new state that some
command has to write anyway.

ADR 0014 said audit history would key on a location's TEXT name. ADR 0022
has since replaced that with `LocationRef`, and audit history follows it.

## Considered options

- **Compose the existing commands plus a stamp-only command vs one
  `CompleteLocationAudit` command.** The single command won, for the same
  reason ADR 0014 added `RelocatePlacedCards`. Three calls are non-atomic: a
  failure between them leaves copies unmarked with no audit recorded, or
  stamped with half the findings applied.
- **Apply unexpected finds immediately vs at completion.** Applying at
  completion won. An immediate move would need its own atomic
  `MovePlacedCards` command. Deferring makes abandoning trivially safe
  (nothing was written) and puts every write into one transaction. The cost
  is that the walk has to survive in the page until it completes. The page
  keeps it in the browser's localStorage, so a reload doesn't lose it,
  re-checked against the fresh ledger on restore.
- **A misfiled copy: mark it here only vs move it from a named source.**
  Moving won. When marking a found copy here would place more copies than are
  owned, it must have come from another location. The user names that
  location, pre-selected when only one location records the copy, the same
  posture as ADR 0023's removal naming its location. Marking it here only
  would leave provably wrong state until the other location happened to be
  audited.

## Decision

- `CompleteLocationAudit(location, missing, unexpected)` validates every
  finding against the current ledger and owned quantities, then in one
  transaction: unmarks the missing copies at the audited location, moves
  sourced unexpected copies from their source, marks unsourced ones here, and
  appends a row to `location_audits`. The first contradiction rejects the
  whole audit with a 400, since the client holds the same ledger and
  projection and only a stale page can send one.
- An unsourced unexpected copy must fit within the copies that are owned but
  not placed anywhere; otherwise it needs a source.
- Copies the collection doesn't own are reported on the page and never sent:
  the audit never writes the collection.
- `location_audits` keys on the `LocationRef` like `placed_cards`, one row per
  completed audit. The latest audit per location is derived, never stored.
  Deleting a deck deletes its audit history with its ledger rows.

## Consequences

- An audit is all-or-nothing on the server. Abandoning, or a page that never
  reaches Complete, leaves the ledger untouched.
- The client duplicates the server's checks (`unresolvedCopies`) to keep
  Complete disabled until every find can be applied. The server stays the
  authority, and a stale page gets an actionable message instead of a
  silent fix.
- An in-progress walk lives in one browser only. It doesn't follow the user
  to another device, and a saved walk the ledger has since moved under is
  dropped with a notice rather than trimmed to fit.
- Renaming a rule target orphans that location's audit history, as it
  orphans its placed rows. `RelocatePlacedCards` doesn't re-point audit
  history.
- The backup export doesn't carry audit history yet, so a restore drops it.
  A restore also leaves existing history in place even though the restored
  ledger may differ.
