import gleam/erlang/charlist
import gleam/string
import shared/domain/os_runtime

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

/// Creates a disposable temp-file SQLite DB, applies all real migrations
/// (their migrate:up sections), sets TCG_DB_FILE for the duration, then
/// cleans up. On test failure the temp file lingers in $TMPDIR — acceptable,
/// the OS will clean it eventually.
pub fn with_temp_db(body: fn(String) -> a) -> a {
  let db_path = string.trim(os_runtime.cmd("mktemp"))

  let apply_script =
    "for f in db/migrations/*.sql; do"
    <> " sed '/-- migrate:down/Q' \"$f\" | sqlite3 "
    <> shell_quote(db_path)
    <> "; done"
  let _ = os_runtime.cmd("sh -c " <> shell_quote(apply_script))

  set_env("TCG_DB_FILE", db_path)

  let result = body(db_path)

  unset_env("TCG_DB_FILE")
  let _ = os_runtime.cmd("rm -f " <> shell_quote(db_path))

  result
}
