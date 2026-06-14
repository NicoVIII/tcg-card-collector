# Backend Architecture

Strict hexagonal layers — each layer may only import itself and layers below it: `domain` → `application` → `infrastructure`/`driver` → `composition`. `common` is available everywhere.

**Request flow**: `skir-src/*.skir` → generated `server/src/driver/skirout/` → handler (`server/src/driver/skir/`) → application port (`server/src/application/`) → domain + infrastructure.

Three bounded contexts under `server/src/domain/`: **Catalog**, **Collection**, **Inventory Planning**. Planning preferences (formerly "Settings") live inside Inventory Planning — there is no separate Settings context.

## Application Layer

CQRS: commands and queries are strictly separated. Commands: `application/commands/<domain>/<command>/`, queries: `application/queries/<domain>/<query>/`. Each use case has its own narrow port — `handler.gleam` (command/query type + `execute`), `ports.gleam` (port interface + errors). No shared repository bundles.

Naming: operation-first — `RefreshCatalogCommand`, `ListCatalogCardsQuery`, `RefreshCatalogPort`.

**Handlers own orchestration.** The `execute` function in `handler.gleam` contains the use-case logic (branching, sequencing, error mapping). It must not be an empty pass-through to a single `port.execute()` god-method. Ports are **capability-narrow**: each field is one specific operation (`is_probe_due`, `fetch_metadata`, `import_cards`, `record_succeeded`, …). The handler composes them.

**Catalog import validation.** Every card imported from Scryfall flows through `card_printing.from_raw` before being persisted. Invalid rows (unknown rarity, empty required fields) are skipped with a per-row warning log; the refresh still succeeds with the valid subset. This is where domain-layer consistency checks live — add new checks to `from_raw`.

## Database

SQLite. Set `TCG_DB_FILE` to the db path. Run migrations with `just dbmate-migrate`.
