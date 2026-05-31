import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/string
import infrastructure/sqlite_store

type SnapshotRowTuple =
  #(String, String, String, Int)

type LatestRunTuple =
  #(String, String, String, Int)

pub fn save(
  id: String,
  source_name: String,
  status: String,
  row_count: Int,
) -> Nil {
  let source_checksum = "manual-upload"
  let finished_at_sql = case status {
    "succeeded" -> "CURRENT_TIMESTAMP"
    "failed" -> "CURRENT_TIMESTAMP"
    _ -> "NULL"
  }

  let sql =
    "INSERT INTO import_runs ("
    <> "  id, source_name, source_checksum, status, started_at, finished_at, imported_row_count"
    <> ") VALUES ("
    <> sqlite_store.quote(id)
    <> ", "
    <> sqlite_store.quote(source_name)
    <> ", "
    <> sqlite_store.quote(source_checksum)
    <> ", "
    <> sqlite_store.quote(status)
    <> ", CURRENT_TIMESTAMP, "
    <> finished_at_sql
    <> ", "
    <> int.to_string(row_count)
    <> ") "
    <> "ON CONFLICT(id) DO UPDATE SET "
    <> "  source_name = excluded.source_name,"
    <> "  source_checksum = excluded.source_checksum,"
    <> "  status = excluded.status,"
    <> "  imported_row_count = excluded.imported_row_count,"
    <> "  finished_at = "
    <> finished_at_sql
    <> ", "
    <> "  updated_at = CURRENT_TIMESTAMP;"

  sqlite_store.exec(sql)
}

pub fn latest() -> Option(LatestRunTuple) {
  let output =
    sqlite_store.query(
      "SELECT id, source_name, status, imported_row_count "
      <> "FROM import_runs "
      <> "ORDER BY updated_at DESC, created_at DESC "
      <> "LIMIT 1;",
    )

  parse_latest(output)
}

pub fn replace_rows(import_run_id: String, rows: List(SnapshotRowTuple)) -> Nil {
  let delete_sql =
    "DELETE FROM collection_snapshot WHERE import_run_id = "
    <> sqlite_store.quote(import_run_id)
    <> ";"

  sqlite_store.exec(delete_sql)
  insert_rows(import_run_id, rows, 1)
}

pub fn clear() -> Nil {
  sqlite_store.exec("DELETE FROM collection_snapshot;")
  sqlite_store.exec("DELETE FROM import_runs;")
}

fn insert_rows(
  import_run_id: String,
  rows: List(SnapshotRowTuple),
  row_number: Int,
) -> Nil {
  case rows {
    [] -> Nil
    [#(card_name, set_code, collector_number, quantity), ..rest] -> {
      let row_id = import_run_id <> "-row-" <> int.to_string(row_number)
      let sql =
        "INSERT INTO collection_snapshot ("
        <> "  id, import_run_id, row_number, card_name, set_code, collector_number, finish, language, quantity"
        <> ") VALUES ("
        <> sqlite_store.quote(row_id)
        <> ", "
        <> sqlite_store.quote(import_run_id)
        <> ", "
        <> int.to_string(row_number)
        <> ", "
        <> sqlite_store.quote(card_name)
        <> ", "
        <> sqlite_store.quote(set_code)
        <> ", "
        <> sqlite_store.quote(collector_number)
        <> ", 'nonfoil', 'en', "
        <> int.to_string(quantity)
        <> ");"

      sqlite_store.exec(sql)
      insert_rows(import_run_id, rest, row_number + 1)
    }
  }
}

fn parse_latest(output: String) -> Option(LatestRunTuple) {
  let trimmed = string.trim(output)
  case trimmed == "" {
    True -> None
    False ->
      case string.split(trimmed, "\t") {
        [id, source_name, status, row_count_raw] ->
          case int.parse(row_count_raw) {
            Ok(row_count) -> Some(#(id, source_name, status, row_count))
            Error(_) -> None
          }
        _ -> None
      }
  }
}
