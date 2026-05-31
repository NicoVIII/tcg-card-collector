import common/os_runtime
import gleam/int
import gleam/string

const default_db_file = "tcg-card-collector.db"

pub fn exec(sql: String) -> Nil {
  ensure_schema()
  let _ = run(sql)
  Nil
}

pub fn query(sql: String) -> String {
  ensure_schema()
  run(sql)
}

pub fn quote(value: String) -> String {
  "'" <> escape_sql(value) <> "'"
}

pub fn quote_int(value: Int) -> String {
  int.to_string(value)
}

fn ensure_schema() -> Nil {
  let _ =
    run(
      "CREATE TABLE IF NOT EXISTS _schema_bootstrap ("
      <> "  id INTEGER PRIMARY KEY CHECK (id = 1),"
      <> "  ready INTEGER NOT NULL DEFAULT 0"
      <> ");",
    )

  case
    string.trim(run("SELECT ready FROM _schema_bootstrap WHERE id = 1 LIMIT 1;"))
  {
    "1" -> Nil
    _ -> {
      apply_migrations()
      let _ =
        run(
          "INSERT INTO _schema_bootstrap (id, ready) VALUES (1, 1) "
          <> "ON CONFLICT(id) DO UPDATE SET ready = 1;",
        )
      Nil
    }
  }
}

fn apply_migrations() -> Nil {
  let script =
    "set -e; "
    <> "for file in server/db/migrations/*.sql; do "
    <> "sqlite3 "
    <> shell_quote(db_file())
    <> " < \"$file\"; "
    <> "done"

  let _ = os_runtime.cmd("sh -c " <> shell_quote(script))
  Nil
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
