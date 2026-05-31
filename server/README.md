# server

Gleam backend scaffold.

Planned layering:
- domain
- application
- infrastructure
- driver
- common
- composition

## Quality

- `gleam format --check src test`
- `gleam check`
- `gleam test`
- `../scripts/check_storage_smoke.sh`
- `../scripts/check_contract_snapshot.sh`
- `../server/linting/check_architecture.sh`

## Database Migrations

- Baseline SQLite migration files live in `server/db/migrations`.
- Current baseline schema:
	- `import_runs` for import history metadata
	- `collection_snapshot` for imported collection snapshot rows
	- `catalog_cards` for minimal catalog card fields
	- `catalog_sync_metadata` for refresh probe and upstream sync metadata
	- `inventory_rules` for persisted inventory rule definitions
	- `app_settings` for persisted default sort/grouping preferences

## Application Ports and Adapters

- Application ports and service modules live in `server/src/application/*`.
- SQLite adapter implementations live in `server/src/infrastructure/*/sqlite_repository.gleam`.
- Thin wiring lives in `server/src/composition.gleam`.

## Driver Layer

- Skir-oriented handlers live in `server/src/driver/skir/*`.
- Handlers map transport request models to application commands and queries.
- HTTP route and mapper baseline lives in `server/src/driver/http/*`.
