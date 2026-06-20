import collection/domain/import_status
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import shared/infrastructure/stores/sqlite_store

type SnapshotRowTuple =
  #(String, String, Int)

type LatestRunTuple =
  #(String, String, import_status.ImportStatus, Int)

pub fn save(
  id: String,
  source_name: String,
  status: import_status.ImportStatus,
  row_count: Int,
) -> Nil {
  let status_str = import_status.to_string(status)
  let finished_at_sql = case status {
    import_status.Succeeded | import_status.Failed -> "CURRENT_TIMESTAMP"
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
    <> sqlite_store.quote("manual-upload")
    <> ", "
    <> sqlite_store.quote(status_str)
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

pub fn snapshot_rows() -> List(SnapshotRowTuple) {
  let output =
    sqlite_store.query(
      "WITH latest_succeeded AS ("
      <> "  SELECT id FROM import_runs"
      <> "  WHERE status = 'succeeded'"
      <> "  ORDER BY updated_at DESC, created_at DESC"
      <> "  LIMIT 1"
      <> ") "
      <> "SELECT s.set_code, s.collector_number, SUM(s.quantity) "
      <> "FROM collection_snapshot s "
      <> "JOIN latest_succeeded ls ON s.import_run_id = ls.id "
      <> "GROUP BY s.set_code, s.collector_number;",
    )

  output
  |> string.split("\n")
  |> list.filter_map(fn(line) {
    case line == "" {
      True -> Error(Nil)
      False ->
        case string.split(line, "\t") {
          [set_code, collector_number, quantity_raw] ->
            case int.parse(quantity_raw) {
              Ok(quantity) -> Ok(#(set_code, collector_number, quantity))
              Error(_) -> Error(Nil)
            }
          _ -> Error(Nil)
        }
    }
  })
}

pub fn replace_rows(
  import_run_id: String,
  rows: List(SnapshotRowTuple),
) -> Nil {
  let delete_sql =
    "DELETE FROM collection_snapshot WHERE import_run_id = "
    <> sqlite_store.quote(import_run_id)
    <> ";"

  sqlite_store.exec(delete_sql)
  insert_rows(import_run_id, rows, 1)
}

fn insert_rows(
  import_run_id: String,
  rows: List(SnapshotRowTuple),
  row_number: Int,
) -> Nil {
  case rows {
    [] -> Nil
    [#(set_code, collector_number, quantity), ..rest] -> {
      let row_id = import_run_id <> "-row-" <> int.to_string(row_number)
      let sql =
        "INSERT INTO collection_snapshot ("
        <> "  id, import_run_id, row_number, set_code, collector_number, finish, language, quantity"
        <> ") VALUES ("
        <> sqlite_store.quote(row_id)
        <> ", "
        <> sqlite_store.quote(import_run_id)
        <> ", "
        <> int.to_string(row_number)
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
        [id, source_name, status_raw, row_count_raw] ->
          case import_status.from_string(status_raw), int.parse(row_count_raw) {
            Ok(status), Ok(row_count) ->
              Some(#(id, source_name, status, row_count))
            _, _ -> None
          }
        _ -> None
      }
  }
}
