import common/os_runtime
import gleam/io
import gleam/string

const default_db_file = "db/tcg-card-collector.db"

pub fn exec(sql: String) -> Nil {
  let inner =
    "sqlite3 -noheader -separator '\t' "
    <> shell_quote(db_file())
    <> " "
    <> shell_quote(sql)
  let wrapped =
    "set +e; " <> inner <> "; status=$?; printf '\\n__EXIT__:%s' \"$status\""
  let output = os_runtime.cmd("sh -c " <> shell_quote(wrapped))
  case string.split(output, "__EXIT__:") {
    [body, status_raw] ->
      case string.trim(status_raw) {
        "0" -> Nil
        _ -> io.println("[sqlite][error] exec failed: " <> string.trim(body))
      }
    _ ->
      io.println(
        "[sqlite][error] exec failed (no exit marker): " <> string.trim(output),
      )
  }
}

pub fn query(sql: String) -> String {
  run(sql)
}

pub fn quote(value: String) -> String {
  "'" <> escape_sql(value) <> "'"
}

fn run(sql: String) -> String {
  let command =
    "sqlite3 -noheader -separator '\t' "
    <> shell_quote(db_file())
    <> " "
    <> shell_quote(sql)

  os_runtime.cmd(command)
}

pub fn db_file() -> String {
  os_runtime.getenv_or("TCG_DB_FILE", default_db_file)
}

fn shell_quote(value: String) -> String {
  "'" <> escape_shell(value) <> "'"
}

fn escape_shell(value: String) -> String {
  string.replace(value, "'", "'\"'\"'")
}

fn escape_sql(value: String) -> String {
  string.replace(value, "'", "''")
}
