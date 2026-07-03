# Backend Architecture

Code is organized **context-first, then layer**: `server/src/<bounded_context>/{domain,application/{commands,queries},infrastructure/{adapters,daos},driver/{skir,http}}/`. Strict hexagonal layers apply within and across contexts — each layer may only import itself and layers below it: `domain` → `application` → `infrastructure`/`driver` → `composition`. `shared/domain` is available everywhere.

## Architecture Rules (enforced by glinter via `server/vendor/gleam-libs/packages/glinter_arch`)

`just server::lint-check` runs `gleam run -m lint` which applies a custom `depends_only_on` rule. Violations are build errors.

- **Bounded context isolation**: `catalog`, `collection`, and `inventory_planning` must not import from each other, except via the explicit cross-BC allowlist (see below). Only `bootstrap/composition` wires them together unconditionally.
- **Layer ordering**: within any context (and within `shared/`), imports may only go inward — `driver`/`infrastructure` may import `application` and `domain`, but not the reverse.
- **`driver/gleam/` is a cross-BC Gleam API layer** (`GleamDriver`): a thin facade that exposes a BC's capabilities to other BCs. A BC's `infrastructure` may import another BC's `driver/gleam/` only if the pair is declared in the allowlist in `test/lint.gleam`. Regular `driver/http/` and `driver/skir/` remain transport-only and are never cross-BC. `GleamDriver` may import its own BC's `domain`, `application`, and `infrastructure` — routing through the owning BC's query handler and adapter, not straight into the DAO, so it returns typed read models instead of raw tuples. **Known gap**: the vendored `glinter_arch` (a separate `gleam-libs` submodule) doesn't yet encode the Driver→own-BC-Infrastructure exception this rule describes, so `driver/gleam/*.gleam` files currently carry a `// nolint: depends_only_on` on the infrastructure import. Fixing the rule itself means changing that submodule.
- **`shared/` is a shared kernel**: any bounded context may import `shared/`, but `shared/` must not import bounded contexts. Layer rules apply within `shared/` too.
- **`bootstrap/` is the composition root**: it may import anything. Only `driver/` may import `bootstrap/` (DI injection seam).
- **Generated skir code** (`src/shared/driver/skir/skirout/`) is linted like handwritten code — it categorizes as shared `Driver(Skir)` and there is no lint exclusion. Only `gleam format` skips it (the `find ... ! -path '*/skirout/*'` in `server/justfile`).

**Current cross-BC allowlist** (declared in `test/lint.gleam`):
- `inventory_planning/infrastructure` → `catalog/driver/gleam/` (via `catalog_api`)
- `inventory_planning/infrastructure` → `collection/driver/gleam/` (via `collection_api`)

Allowlist additions must stay explicit one-to-one context pairs — no wildcards or blanket layer bypasses.

Three bounded contexts under `server/src/`: **catalog**, **collection**, **inventory_planning**. Planning preferences live inside inventory_planning — there is no separate Settings context. Domain vocabulary and context ownership rules: read `docs/dev/domain-ubiquitous-language.md` before touching domain code.

All three bounded contexts share the same driver pattern: drivers call use-case handlers directly — there is no intermediate application facade. Result mapping from domain types to RPC types lives in `driver/skir/codec.gleam`; route handlers and JSON encoding/decoding live in `driver/http/handler.gleam` and `driver/http/json_codec.gleam`.

**Request flow (skir)**: `skir-src/*.skir` → generated `server/src/shared/driver/skir/skirout/` → `server/src/<context>/driver/skir/handler.gleam` → use-case handler → use-case port → domain + infrastructure. Result mapping to RPC types is done via `driver/skir/codec.gleam`.

**Request flow (http)**: `bootstrap/http/app_server.gleam` routing table → `server/src/<context>/driver/http/handler.gleam` → use-case handler → use-case port → domain + infrastructure. HTTP context drivers split into `handler.gleam` (route handlers) + `json_codec.gleam` (encoders/decoders).

Shared cross-context code lives under `server/src/shared/`: `shared/domain/` (shared kernel — `card_key`, `non_empty_string`; pure, no I/O), `shared/application/command_result.gleam` (shared app type), `shared/infrastructure/` (shared infra — `os_runtime` (raw `os:cmd`/`getenv`), `shell.gleam` (subprocess wrapper), `stores/sqlite_store.gleam` (parameterized queries over `sqlight`)), `shared/driver/` (shared transport code — `http/{helpers,json_codec}.gleam` (generic response helpers, shared encoders/decoders) and `skir/skirout/` (generated contract code — never edit, run `just skir-gen`)). Database access objects for each context live in `<context>/infrastructure/daos/`. Bootstrap/composition layer under `server/src/bootstrap/`: `bootstrap/skir/{router,setup}.gleam` (skir server loop + thin `make_service()` chaining context registers), `bootstrap/http/app_server.gleam` (mist bootstrap, routing table), `bootstrap/composition.gleam` (DI wiring root).

**Two transports, deliberately.** skir (contract-first RPC) is the primary, well-typed API the client-web app uses. A parallel REST API exists for third-party/scripted access where requiring the skir client isn't practical — it is not legacy and both are expected to stay. Because of this, a use case that has externally-visible side effects (e.g. spawning a background worker) must put that orchestration in a shared module both drivers call (e.g. `catalog/driver/refresh_launcher.gleam`), not duplicate it per transport — the two doors must behave identically, they just speak different wire formats.

**`catalog_dao.bulk_load` is a deliberate exception to "no raw SQL strings, use sqlight"**: it shells out to the `sqlite3` CLI's `.import` for bulk-loading the ~90k-row Scryfall CSV dump. This is safe because the input is our own `scryfall_mapper` output, not user-supplied text — the injection risk that motivated moving everything else to `sqlight` doesn't apply here, and CLI bulk import is meaningfully faster than row-by-row parameterized inserts at this volume.

## Application Layer

CQRS: commands and queries are strictly separated. Commands: `<context>/application/commands/<command>/`, queries: `<context>/application/queries/<query>/`. Each use case has its own `handler.gleam` (command/query type + `execute`) and `ports.gleam` (port interfaces + errors).

Naming: operation-first — `RefreshCatalogCommand`, `ListCatalogCardsQuery`, `RefreshCatalogPorts`.

**Port naming and structure.** A use case that depends on a **single capability** defines one `*Port` type (e.g. `ListCatalogCardsPort`). A use case that depends on **multiple capabilities** defines individual named port types and bundles them in a `*Ports` aggregate record (e.g. `RefreshCatalogPorts`). Each port is either:
- A `fn`-type alias (`pub type NowPort = fn() -> Timestamp`) for a single-op port.
- A small record for a cohesively-grouped multi-op port (e.g. `RefreshRecordRepositoryPort` with `load`/`save` — the aggregate's consistency boundary).

Ports are **capability-narrow**: each function declares only what the use case needs. Reuse belongs in the infrastructure layer behind adapters, not in widened port signatures. No sharing of repository ports across use cases — each use case owns its own port definitions.

**Adapters wire one typed function per port** and assemble the `*Ports` record. Each per-port adapter function carries the port type alias as its return type annotation.

**Handlers own orchestration — for commands.** A command's `execute` must not be an empty pass-through to a single `ports.execute()` god-method; it contains the use-case logic (branching, sequencing, error mapping) and composes the individual ports from the `*Ports` bundle. **Queries are exempt**: a query handler that is a one-line `port.f()` (e.g. `ListCatalogCardsQuery`, `GetPlanningPreferencesQuery`) is not hiding logic — there just isn't any — and is the CQRS-orthodox shape for a read that has nothing to branch on. Don't invent branching in a query handler just to avoid looking thin.

## Infrastructure Layer

**Injected-IO seam for testability.** Adapters that make network calls accept a seam type (e.g. `scryfall_client.Downloader`) holding the outbound I/O as a closure, injected via a `new_with_*` constructor. `new()` calls `new_with_*(live_*())` for production. This lets integration tests pass a hermetic fake without touching `composition.gleam`.

## Database

SQLite via `sqlight` (parameterized queries, typed decoders) through `shared/infrastructure/stores/sqlite_store.gleam` — DAOs should not build SQL by string-interpolating values; use `?` placeholders and `sqlight.text`/`sqlight.int`/`sqlight.nullable`. Set `TCG_DB_FILE` to the db path. Run migrations with `just dbmate-migrate`. Write ports return `Result(Nil, String)`; the calling handler decides what a persistence failure means for its use case (e.g. a failed snapshot write fails the import, but a failed progress-marker write is swallowed on purpose since it's advisory only).
