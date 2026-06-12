# Backend Architecture

Strict hexagonal layers — each layer may only import itself and layers below it: `domain` → `application` → `infrastructure`/`driver` → `composition`. `common` is available everywhere. Enforced by `just server::lint-check`.

Layer violations require a named exception in `server/linting/architecture_exceptions.txt` (`source/module -> target/module`). Temporary only — no wildcards.

**Request flow**: `skir-src/*.skir` → generated `server/src/driver/skirout/` → handler (`server/src/driver/skir/`) → application port (`server/src/application/`) → domain + infrastructure.

Three bounded contexts under `server/src/domain/`: Card Catalog, Collection Import, Inventory Planning.

## Database

SQLite. Set `TCG_DB_FILE` to the db path. Run migrations with `just dbmate-migrate`.
