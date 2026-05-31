import common/os_runtime
import gleam/int
import gleam/string

const default_db_file = "db/tcg-card-collector.db"

pub fn exec(sql: String) -> Nil {
  let _ = run(sql)
  Nil
}

pub fn query(sql: String) -> String {
  run(sql)
}

pub fn quote(value: String) -> String {
  "'" <> escape_sql(value) <> "'"
}

pub fn quote_int(value: Int) -> String {
  int.to_string(value)
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
