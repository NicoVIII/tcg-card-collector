# Card Catalog

Context-specific rules; cross-context rules live in `server/AGENTS.md`.

- **`catalog_dao.bulk_load` is a deliberate exception to "no raw SQL strings,
  use sqlight"**: it shells out to the `sqlite3` CLI's `.import` for
  bulk-loading the ~90k-row Scryfall CSV dump. This is safe because the input
  is our own `scryfall_mapper` output, not user-supplied text — the injection
  risk that motivated moving everything else to `sqlight` doesn't apply here,
  and CLI bulk import is meaningfully faster than row-by-row parameterized
  inserts at this volume. Don't "fix" it back to parameterized inserts.
  Decision record:
  [ADR 0005](../../../docs/decisions/0005-bulk-load-via-sqlite3-cli-import.md).
- **`driver/refresh_launcher.gleam` is the shared orchestration module** for
  the refresh use case's background worker — both the skir and http drivers
  must go through it (see the two-transports rule in `server/AGENTS.md`).
- **`catalog_cards.color_identity` stores Scryfall's raw spelling** —
  alphabetical letter order as the dump ships it (e.g. `UW`, not canonical
  `WU`). Canonical WUBRG order exists only after parsing into the shared
  `ColorIdentity` type. Never string-match canonical forms in SQL against this
  column.
- **A migration that adds or backfills a `catalog_cards` column must force a
  full reload.** The data for any such column comes from the Scryfall bulk
  dump, and `catalog_dao.bulk_load` is `DELETE` + reinsert — there is no
  incremental path, so the new column stays NULL until the next full import.
  The gate that decides whether a refresh runs at all is
  `refresh_record.is_probe_due`, keyed on `catalog_sync_metadata.last_probe_at`
  with a 24h interval; `refresh_record.decide`'s read of
  `last_upstream_updated_at` only runs after that gate passes. **Nulling
  `last_upstream_updated_at` alone does not force anything** — `is_probe_due`
  never looks at it, and an instance that probed within the last 24h will
  skip the refresh entirely with no error (#114; this is what 0005, 0011,
  0012, 0013, and 0018 did wrong — don't copy them). The one supported way to
  request a reset is to clear the whole record, which both gates read as
  "never probed":
  ```sql
  DELETE FROM catalog_sync_metadata;
  ```
  The reload happens on the next boot or manual Refresh press, not at
  migration time — a full bulk download plus reinsert, taking a few minutes.
  Until it completes, the Catalog page reports `never_run` and the new column
  reads NULL for existing rows.
