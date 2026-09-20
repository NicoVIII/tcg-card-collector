import gleam/erlang/charlist
import gleam/string
import shared/infrastructure/os_runtime

@external(erlang, "os", "putenv")
fn erl_putenv(name: charlist.Charlist, value: charlist.Charlist) -> Bool

@external(erlang, "os", "unsetenv")
fn erl_unsetenv(name: charlist.Charlist) -> Bool

fn set_env(name: String, value: String) -> Nil {
  let _ = erl_putenv(charlist.from_string(name), charlist.from_string(value))
  Nil
}

fn unset_env(name: String) -> Nil {
  let _ = erl_unsetenv(charlist.from_string(name))
  Nil
}

fn shell_quote(value: String) -> String {
  "'" <> string.replace(value, "'", "'\"'\"'") <> "'"
}

fn create_temp_db() -> String {
  string.trim(os_runtime.cmd("mktemp"))
}

/// Applies one migration file's `migrate:up` section (only) to `db_path`.
fn apply_up_section(db_path: String, migration_file: String) -> Nil {
  let script =
    "sed '/-- migrate:down/Q' "
    <> shell_quote(migration_file)
    <> " | sqlite3 "
    <> shell_quote(db_path)
  let _ = os_runtime.cmd("sh -c " <> shell_quote(script))
  Nil
}

/// Applies every `migrate:up` section under `db/migrations/`, in filename
/// order.
fn apply_all_up(db_path: String) -> Nil {
  let script =
    "for f in db/migrations/*.sql; do"
    <> " sed '/-- migrate:down/Q' \"$f\" | sqlite3 "
    <> shell_quote(db_path)
    <> "; done"
  let _ = os_runtime.cmd("sh -c " <> shell_quote(script))
  Nil
}

/// Applies every `migrate:up` section up to, but not including, the
/// migration named by `stop_before` (a filename stem, e.g.
/// "0016_collection_copy_key") — filename order decides "before", same as
/// dbmate. Left unquoted so the trailing `*` stays a glob, not a literal
/// character — quoting any part of a `case` pattern disables matching on it.
fn apply_up_before(db_path: String, stop_before: String) -> Nil {
  let script =
    "for f in db/migrations/*.sql; do"
    <> " case \"$(basename \"$f\")\" in "
    <> shell_quote(stop_before)
    <> "*) break;; esac;"
    <> " sed '/-- migrate:down/Q' \"$f\" | sqlite3 "
    <> shell_quote(db_path)
    <> "; done"
  let _ = os_runtime.cmd("sh -c " <> shell_quote(script))
  Nil
}

fn run_sql_file(db_path: String, sql_file: String) -> Nil {
  let script =
    "sqlite3 " <> shell_quote(db_path) <> " < " <> shell_quote(sql_file)
  let _ = os_runtime.cmd("sh -c " <> shell_quote(script))
  Nil
}

/// Sets `TCG_DB_FILE` to `db_path` for the duration of `body`, then unsets it
/// and deletes the temp file. On test failure the temp file lingers in
/// $TMPDIR — acceptable, the OS will clean it eventually.
fn with_db_file_env(db_path: String, body: fn() -> a) -> a {
  set_env("TCG_DB_FILE", db_path)
  let result = body()
  unset_env("TCG_DB_FILE")
  let _ = os_runtime.cmd("rm -f " <> shell_quote(db_path))
  result
}

/// Creates a disposable temp-file SQLite DB, applies all real migrations
/// (their migrate:up sections), sets TCG_DB_FILE for the duration, then
/// cleans up.
pub fn with_temp_db(body: fn(String) -> a) -> a {
  let db_path = create_temp_db()
  apply_all_up(db_path)
  with_db_file_env(db_path, fn() { body(db_path) })
}

/// Seeds a populated database at the schema immediately *before* `migration`,
/// then applies `migration` itself — so `body` can assert on what survived
/// the upgrade, proving the migration preserves data rather than merely
/// producing the right empty schema.
///
/// `migration` is a filename stem under `db/migrations/`
/// (e.g. "0016_collection_copy_key"); the seed is read by convention from
/// `test/migrations/seeds/<migration>.sql`, written against the schema one
/// migration earlier. `body` reads the result back through whatever DAO or
/// query owns the table — it picks up the TCG_DB_FILE this sets.
pub fn with_seeded_upgrade(migration: String, body: fn() -> a) -> a {
  let db_path = create_temp_db()
  apply_up_before(db_path, migration)
  run_sql_file(db_path, "test/migrations/seeds/" <> migration <> ".sql")
  apply_up_section(db_path, "db/migrations/" <> migration <> ".sql")
  with_db_file_env(db_path, body)
}
