# Card Catalog

Context-specific rules; cross-context rules live in `server/AGENTS.md`.

- **`catalog_dao.bulk_load` is a deliberate exception to "no raw SQL strings,
  use sqlight"**: it shells out to the `sqlite3` CLI's `.import` for
  bulk-loading the ~90k-row Scryfall CSV dump. This is safe because the input
  is our own `scryfall_mapper` output, not user-supplied text — the injection
  risk that motivated moving everything else to `sqlight` doesn't apply here,
  and CLI bulk import is meaningfully faster than row-by-row parameterized
  inserts at this volume. Don't "fix" it back to parameterized inserts.
- **`driver/refresh_launcher.gleam` is the shared orchestration module** for
  the refresh use case's background worker — both the skir and http drivers
  must go through it (see the two-transports rule in `server/AGENTS.md`).
