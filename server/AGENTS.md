# Backend Architecture

Code is organized **context-first, then layer**: `server/src/<bounded_context>/{domain,application/{commands,queries},infrastructure/{adapters,stores},skir}/`. Strict hexagonal layers apply within and across contexts — each layer may only import itself and layers below it: `domain` → `application` → `infrastructure`/`skir`/`http` → `composition`. `common` is available everywhere.

Three bounded contexts under `server/src/`: **catalog**, **collection**, **inventory_planning**. Planning preferences (formerly "Settings") live inside inventory_planning — there is no separate Settings context.

**Request flow**: `skir-src/*.skir` → generated `server/src/skir/skirout/` → handler (`server/src/<context>/skir/handler.gleam`) → application port (`server/src/<context>/application/`) → domain + infrastructure.

Shared cross-context code: `common/` (shared kernel), `application/command_result.gleam` (shared app type), `infrastructure/stores/sqlite_store.gleam` (shared infra), `skir/{router,setup}.gleam` + `skir/skirout/` (shared skir adapter), `http/{app_server,json_codec}.gleam` (shared http adapter).

## Application Layer

CQRS: commands and queries are strictly separated. Commands: `<context>/application/commands/<command>/`, queries: `<context>/application/queries/<query>/`. Each use case has its own narrow port — `handler.gleam` (command/query type + `execute`), `ports.gleam` (port interface + errors). No shared repository bundles.

Naming: operation-first — `RefreshCatalogCommand`, `ListCatalogCardsQuery`, `RefreshCatalogPort`.

**Handlers own orchestration.** The `execute` function in `handler.gleam` contains the use-case logic (branching, sequencing, error mapping). It must not be an empty pass-through to a single `port.execute()` god-method. Ports are **capability-narrow**: each field is one specific operation (`is_probe_due`, `fetch_metadata`, `import_cards`, `record_succeeded`, …). The handler composes them.

**Catalog import validation.** Every card imported from Scryfall flows through `card_printing.from_raw` before being persisted. Invalid rows (unknown rarity, empty required fields) are skipped with a per-row warning log; the refresh still succeeds with the valid subset. This is where domain-layer consistency checks live — add new checks to `from_raw`.

## Database

SQLite. Set `TCG_DB_FILE` to the db path. Run migrations with `just dbmate-migrate`.
