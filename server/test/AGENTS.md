# Test Suite

Integration tests live under `test/integration/`, which tests infrastructure adapters against a real (but disposable) SQLite DB with only the **network** faked via an injected IO seam.

## Layout convention

The `test/integration/` subtree mirrors `src/`, but the `adapters/` segment is dropped from the path: `test/integration/infrastructure/commands/database/refresh/adapter_test.gleam` (not `…/adapters/commands/…`).

## Shared helpers vs. slice-local

- `test/support/` — cross-cutting helpers used by multiple slices (e.g. `test_db.gleam`, `call_log.gleam`).
- Fixtures and inline fakes that are specific to one slice stay **inside that slice's directory**.

## DB provisioning (`test/support/test_db.gleam`)

Use `with_temp_db(fn(db_file) { … })`. It:

1. Creates a temp **file** DB (not `:memory:` — `sqlite_store` spawns a fresh `sqlite3` process per call, so an in-memory DB cannot persist across calls).
2. Applies the real migrations' `migrate:up` sections (strips the `migrate:down` block with `sed '/-- migrate:down/Q'`) so there is never schema drift.
3. Sets `TCG_DB_FILE` for the duration of the test body.
4. Removes the file when done.

## Test discovery and assertions

gleeunit auto-discovers every `pub fn *_test()` in `test/`. Use the `assert` keyword for assertions.
