# Backend Architecture

Strict hexagonal layers — each layer may only import itself and layers below it: `domain` → `application` → `infrastructure`/`driver` → `composition`. `common` is available everywhere. Enforced by `just server::lint-check`.

Layer violations require a named exception in `server/linting/architecture_exceptions.txt` (`source/module -> target/module`). Temporary only — no wildcards.

**Request flow**: `skir-src/*.skir` → generated `server/src/driver/skirout/` → handler (`server/src/driver/skir/`) → application port (`server/src/application/`) → domain + infrastructure.

Three bounded contexts under `server/src/domain/`: Card Catalog, Collection Import, Inventory Planning.

## Application Layer

Commands: `application/commands/<domain>/<command>/`, queries: `application/queries/<domain>/<query>/`. Each use case has its own narrow port — `handler.gleam` (command/query type + `execute`), `ports.gleam` (port interface + errors). No shared repository bundles.

Naming: operation-first — `RefreshDatabaseCommand`, `ListDatabaseCardsQuery`, `RefreshDatabasePort`.

**Handlers own orchestration.** The `execute` function in `handler.gleam` contains the use-case logic (branching, sequencing, error mapping). It must not be an empty pass-through to a single `port.execute()` god-method. Ports are **capability-narrow**: each field is one specific operation (`is_probe_due`, `fetch_metadata`, `import_cards`, `record_succeeded`, …). The handler composes them.

**Note**: "Card Catalog" in `domain/` is called "database" in the application and infrastructure layers — intentional, reflects the concept rather than the domain model name.

## Database

SQLite. Set `TCG_DB_FILE` to the db path. Run migrations with `just dbmate-migrate`.
