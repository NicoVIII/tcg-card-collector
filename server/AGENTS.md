# Backend Architecture

Code is organized **context-first, then layer**: `server/src/<bounded_context>/{domain,application/{commands,queries},infrastructure/{adapters,daos},driver/{skir,http}}/`. Strict hexagonal layers apply within and across contexts — each layer may only import itself and layers below it: `domain` → `application` → `infrastructure`/`driver` → `composition`. `shared/domain` is available everywhere.

## Architecture Rules (enforced by glinter via `server/vendor/gleam-libs/packages/glinter_arch`)

`just server::lint-check` runs `gleam run -m lint` which applies a custom `depends_only_on` rule. Violations are build errors.

- **Bounded context isolation**: `catalog`, `collection`, and `inventory_planning` must not import from each other, except via the explicit cross-BC allowlist (see below). Only `bootstrap/composition` wires them together unconditionally.
- **Layer ordering**: within any context (and within `shared/`), imports may only go inward — `driver`/`infrastructure` may import `application` and `domain`, but not the reverse.
- **`driver/gleam/` is a cross-BC Gleam API layer** (`GleamDriver`): a thin facade that exposes a BC's capabilities to other BCs. A BC's `infrastructure` may import another BC's `driver/gleam/` only if the pair is declared in the allowlist in `test/lint.gleam`. Regular `driver/http/` and `driver/skir/` remain transport-only and are never cross-BC. `GleamDriver` may import its own BC's `domain`, `application`, and `infrastructure`.
- **`shared/` is a shared kernel**: any bounded context may import `shared/`, but `shared/` must not import bounded contexts. Layer rules apply within `shared/` too.
- **`bootstrap/` is the composition root**: it may import anything. Only `driver/` may import `bootstrap/` (DI injection seam).
- **Excluded from linting**: `src/bootstrap/skir/skirout/` (generated code).

**Current cross-BC allowlist** (declared in `test/lint.gleam`):
- `inventory_planning/infrastructure` → `catalog/driver/gleam/` (via `catalog_api`)
- `inventory_planning/infrastructure` → `collection/driver/gleam/` (via `collection_api`)

Three bounded contexts under `server/src/`: **catalog**, **collection**, **inventory_planning**. Planning preferences live inside inventory_planning — there is no separate Settings context.

All three bounded contexts share the same driver pattern: drivers call use-case handlers directly — there is no intermediate application facade. Result mapping from domain types to RPC types lives in `driver/skir/codec.gleam`; route handlers and JSON encoding/decoding live in `driver/http/handler.gleam` and `driver/http/json_codec.gleam`.

**Request flow (skir)**: `skir-src/*.skir` → generated `server/src/bootstrap/skir/skirout/` → `server/src/<context>/driver/skir/handler.gleam` → use-case handler → use-case port → domain + infrastructure. Result mapping to RPC types is done via `driver/skir/codec.gleam`.

**Request flow (http)**: `bootstrap/http/app_server.gleam` routing table → `server/src/<context>/driver/http/handler.gleam` → use-case handler → use-case port → domain + infrastructure. HTTP context drivers split into `handler.gleam` (route handlers) + `json_codec.gleam` (encoders/decoders).

Shared cross-context code lives under `server/src/shared/`: `shared/domain/` (shared kernel — `card_key`, `non_empty_string`, `os_runtime`), `shared/application/command_result.gleam` (shared app type), `shared/infrastructure/stores/sqlite_store.gleam` (shared infra). Database access objects for each context live in `<context>/infrastructure/daos/`. Bootstrap/composition layer under `server/src/bootstrap/`: `bootstrap/skir/{router,setup}.gleam` + `bootstrap/skir/skirout/` (skir server loop + thin `make_service()` chaining context registers), `bootstrap/http/{app_server,json_codec,helpers}.gleam` (mist bootstrap, routing table, generic response helpers), `bootstrap/composition.gleam` (DI wiring root).

## Application Layer

CQRS: commands and queries are strictly separated. Commands: `<context>/application/commands/<command>/`, queries: `<context>/application/queries/<query>/`. Each use case has its own `handler.gleam` (command/query type + `execute`) and `ports.gleam` (port interfaces + errors).

Naming: operation-first — `RefreshCatalogCommand`, `ListCatalogCardsQuery`, `RefreshCatalogPorts`.

**Port naming and structure.** A use case that depends on a **single capability** defines one `*Port` type (e.g. `ListCatalogCardsPort`). A use case that depends on **multiple capabilities** defines individual named port types and bundles them in a `*Ports` aggregate record (e.g. `RefreshCatalogPorts`). Each port is either:
- A `fn`-type alias (`pub type NowPort = fn() -> Timestamp`) for a single-op port.
- A small record for a cohesively-grouped multi-op port (e.g. `RefreshRecordRepositoryPort` with `load`/`save` — the aggregate's consistency boundary).

Ports are **capability-narrow**: each function declares only what the use case needs. Reuse belongs in the infrastructure layer behind adapters, not in widened port signatures. No sharing of repository ports across use cases — each use case owns its own port definitions.

**Adapters wire one typed function per port** and assemble the `*Ports` record. Each per-port adapter function carries the port type alias as its return type annotation.

**Handlers own orchestration.** The `execute` function in `handler.gleam` contains the use-case logic (branching, sequencing, error mapping). It must not be an empty pass-through to a single `ports.execute()` god-method. The handler composes the individual ports from the `*Ports` bundle.

## Infrastructure Layer

**Injected-IO seam for testability.** Adapters that make network calls accept a seam type (e.g. `scryfall_client.Downloader`) holding the outbound I/O as a closure, injected via a `new_with_*` constructor. `new()` calls `new_with_*(live_*())` for production. This lets integration tests pass a hermetic fake without touching `composition.gleam`.

## Database

SQLite. Set `TCG_DB_FILE` to the db path. Run migrations with `just dbmate-migrate`.
