# Backend Architecture

Code is organized **context-first, then layer**: `server/src/<bounded_context>/{domain,application/{commands,queries},infrastructure/{adapters,stores},driver/{skir,http}}/`. Strict hexagonal layers apply within and across contexts — each layer may only import itself and layers below it: `domain` → `application` → `infrastructure`/`driver` → `composition`. `common` is available everywhere.

Three bounded contexts under `server/src/`: **catalog**, **collection**, **inventory_planning**. Planning preferences live inside inventory_planning — there is no separate Settings context.

**Context facade**: each context exposes a transport-agnostic service at `<context>/application/handler.gleam`. It calls use-case handlers and returns simplified types (`Success`/`Failed`, `Accepted`/`Rejected`, …). Both `driver/skir/handler.gleam` and `driver/http/handler.gleam` import it — no transport concern leaks into the application layer.

**Request flow (skir)**: `skir-src/*.skir` → generated `server/src/skir/skirout/` → `server/src/<context>/driver/skir/handler.gleam` → context facade (`<context>/application/handler.gleam`) → use-case port → domain + infrastructure.

**Request flow (http)**: `http/app_server.gleam` routing table → `server/src/<context>/driver/http/handler.gleam` → context facade → use-case port → domain + infrastructure. HTTP context drivers split into `handler.gleam` (route handlers) + `json_codec.gleam` (encoders/decoders).

Shared cross-context code: `common/` (shared kernel), `application/command_result.gleam` (shared app type), `infrastructure/stores/sqlite_store.gleam` (shared infra). Shared transport aggregators: `skir/{router,setup}.gleam` + `skir/skirout/` (skir server loop + thin `make_service()` chaining context registers), `http/{app_server,json_codec,helpers}.gleam` (mist bootstrap, routing table, generic response helpers).

## Application Layer

CQRS: commands and queries are strictly separated. Commands: `<context>/application/commands/<command>/`, queries: `<context>/application/queries/<query>/`. Each use case has its own narrow port — `handler.gleam` (command/query type + `execute`), `ports.gleam` (port interface + errors). No shared repository bundles.

Naming: operation-first — `RefreshCatalogCommand`, `ListCatalogCardsQuery`, `RefreshCatalogPort`.

**Handlers own orchestration.** The `execute` function in `handler.gleam` contains the use-case logic (branching, sequencing, error mapping). It must not be an empty pass-through to a single `port.execute()` god-method. Ports are **capability-narrow**: each field is one specific operation (`fetch_metadata`, `import_cards`, `now`, …). The handler composes them. **Exception:** domain aggregates use a repository shape — `load_record`/`save_record` — because the aggregate is the consistency boundary; stateless I/O effects stay narrow.

## Database

SQLite. Set `TCG_DB_FILE` to the db path. Run migrations with `just dbmate-migrate`.
