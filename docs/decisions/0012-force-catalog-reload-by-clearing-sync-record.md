# 0012 — Force a catalog reload by clearing the sync record

- Status: accepted
- Date: 2026-09-19

## Context

A migration that adds or backfills a `catalog_cards` column (e.g. `cmc` in
`0018_catalog_card_cmc.sql`) needs the next refresh to do a full reload —
`catalog_dao.bulk_load` is `DELETE` + reinsert, so there is no incremental way
to fill a new column for rows already in the table.

Five migrations (`0005`, `0011`, `0012`, `0013`, `0018`) tried to force this by
running `UPDATE catalog_sync_metadata SET last_upstream_updated_at = NULL;`.
That field is read only by `refresh_record.decide`, which runs *after*
`refresh_record.is_probe_due` — a separate gate keyed on
`catalog_sync_metadata.last_probe_at` with a 24h politeness interval
(`server/src/card_catalog/application/commands/refresh/handler.gleam`). On an
instance that had probed within the last 24 hours, `is_probe_due` returned
`False` and the handler returned `Ok(Nil)` without ever reaching `decide`. The
migration's nulled field was never read; the new column stayed NULL
indefinitely with no error surfaced anywhere (#114). The five migrations only
appeared to work because each shipped to instances where more than 24h had
already elapsed since the last probe.

A fix needs to force a reload regardless of how recently the instance last
probed, while leaving the 24h backoff intact for normal automatic checks —
Scryfall's dump doesn't need polling more often than that, and hammering it on
every restart would be rude.

## Considered options

- **Clear the whole `catalog_sync_metadata` record** (`DELETE FROM
  catalog_sync_metadata;`) — both gates already treat "no prior record" as
  "everything is due": `is_probe_due(None, _) -> True` and
  `decide(None, _) -> Import`. A migration needs only this one line; no schema
  change, no new domain concept.
- **`catalog_schema_generation` counter** — add an integer column to
  `catalog_sync_metadata` that migrations bump and a constant in
  `refresh_record` compares against, `is_probe_due` returning `True` whenever
  they differ. Makes "the catalog was loaded by an older schema" an explicit,
  named fact rather than an inference from absence, and could also force a
  reload from a code-only change (e.g. a `scryfall_mapper` fix) with no
  accompanying migration. Rejected for now: a migration containing only the
  `DELETE` above already covers that case in practice — every reload trigger
  to date has come with a migration — so the counter buys a capability nothing
  yet needs, at the cost of a new column, a new domain-level source of truth,
  and a second reset mechanism to keep in sync with the first.
- **Derived per-column checks** (e.g. `SELECT count(*) FROM catalog_cards
  WHERE cmc IS NULL`) — the issue itself calls this out as not generalizing:
  it's bespoke per column and doesn't cover a migration that changes
  interpretation without adding a nullable column. Rejected.

## Decision

A migration that needs the catalog to reload runs:

```sql
DELETE FROM catalog_sync_metadata;
```

This is documented as the one supported mechanism in
`server/src/card_catalog/AGENTS.md`. No schema or domain-type change
accompanies it — `refresh_record`'s existing `None` handling in both
`is_probe_due` and `decide` is what makes the reset work, and both functions'
doc comments now say so.

## Consequences

- **Easier**: no new column, port, or domain concept to keep in sync; the fix
  is a one-line migration plus a doc rule. `refresh_record`'s existing
  `None`-means-"never probed" semantics do double duty as the reset
  mechanism, so there's exactly one thing to understand.
- **Harder / accepted debt**: the reset works by convention, not by a field
  that names its own purpose. If a future gate reads state living outside
  `catalog_sync_metadata` (unlikely today, since the refresh's only durable
  state is that one row), clearing it stops being sufficient and this same
  bug shape recurs — nothing in the type system prevents that, only the
  regression test in `refresh_adapter_test.gleam` and the AGENTS.md rule. If
  a reload ever needs triggering from a code-only change with no migration
  (no schema touched), this mechanism has no answer; the generation-counter
  option above is the fallback design, deliberately not built now that
  nothing needs it.
- A reset discards the last probe's diagnostic fields (`last_refresh_status`,
  `last_error_message`) along with the fields that matter for the gate; the
  next probe rewrites them, so this is a one-probe-cycle loss of debugging
  history, not data the domain owns.
- Between the migration applying and the reload completing, the Catalog page
  reports `never_run` (a legitimate value the read model already produces for
  "no record"), and a not-due refresh still writes nothing, so the page can
  show a stuck "Refreshing…" if the user presses the button while a boot
  refresh is already in flight — this half of #114 is deliberately left to
  #90, which reworks the status surface to expose an in-progress refresh
  directly instead of inferring it from record staleness.
