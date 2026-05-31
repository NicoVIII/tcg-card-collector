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
- `../server/linting/check_architecture.sh`

## Database Migrations

- Baseline SQLite migration files live in `server/db/migrations`.
- Phase 2.3 baseline schema:
	- `import_runs` for import history metadata
	- `collection_snapshot` for imported collection snapshot rows

## Application Ports and Adapters

- Application ports and service modules live in `server/src/application/*`.
- SQLite adapter implementations live in `server/src/infrastructure/*/sqlite_repository.gleam`.
- Thin wiring lives in `server/src/composition.gleam`.
