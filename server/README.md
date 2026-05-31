# server

Gleam backend service for tcg-card-collector.

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

- SQLite migration files live in `server/db/migrations`.
- Apply migrations with `dbmate` (source of truth for schema):
	- `../scripts/install_dbmate.sh`
	- `TCG_DB_FILE=./db/tcg-card-collector.db ../scripts/dbmate_up.sh`
- Current schema:
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
- HTTP routes and mappers live in `server/src/driver/http/*`.
