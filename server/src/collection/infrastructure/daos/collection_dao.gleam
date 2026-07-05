import collection/domain/import_status
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import shared/infrastructure/stores/sqlite_store
import sqlight

type SnapshotRowTuple =
  #(String, String, Int)

type LatestRunTuple =
  #(String, String, import_status.ImportStatus, Int)

const insert_batch_size = 100

pub fn save(
  id: String,
  source_name: String,
  status: import_status.ImportStatus,
  row_count: Int,
) -> Result(Nil, String) {
  let status_str = import_status.to_string(status)
  let finished_at_sql = case status {
    import_status.Succeeded | import_status.Failed -> "CURRENT_TIMESTAMP"
    _ -> "NULL"
  }

  let sql =
    "INSERT INTO import_runs ("
    <> "  id, source_name, source_checksum, status, started_at, finished_at, imported_row_count"
    <> ") VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP, "
    <> finished_at_sql
    <> ", ?) "
    <> "ON CONFLICT(id) DO UPDATE SET "
    <> "  source_name = excluded.source_name,"
    <> "  source_checksum = excluded.source_checksum,"
    <> "  status = excluded.status,"
    <> "  imported_row_count = excluded.imported_row_count,"
    <> "  finished_at = "
    <> finished_at_sql
    <> ", "
    <> "  updated_at = CURRENT_TIMESTAMP;"

  let params = [
    sqlight.text(id),
    sqlight.text(source_name),
    sqlight.text("manual-upload"),
    sqlight.text(status_str),
    sqlight.int(row_count),
  ]

  sqlite_store.exec(sql, params)
  |> result.map_error(fn(error) { error.message })
}

fn latest_row_decoder() {
  use id <- decode.field(0, decode.string)
  use source_name <- decode.field(1, decode.string)
  use status_str <- decode.field(2, decode.string)
  use row_count <- decode.field(3, decode.int)
  decode.success(#(id, source_name, status_str, row_count))
}

pub fn latest() -> Result(Option(LatestRunTuple), String) {
  let rows =
    sqlite_store.query(
      "SELECT id, source_name, status, imported_row_count "
        <> "FROM import_runs "
        <> "ORDER BY updated_at DESC, created_at DESC, rowid DESC "
        <> "LIMIT 1;",
      [],
      latest_row_decoder(),
    )
  case rows {
    Ok([]) -> Ok(None)
    Ok([#(id, source_name, status_str, row_count), ..]) ->
      case import_status.from_string(status_str) {
        Ok(status) -> Ok(Some(#(id, source_name, status, row_count)))
        Error(_) -> Error("invalid persisted import status: " <> status_str)
      }
    Error(error) -> Error(error.message)
  }
}

fn snapshot_row_decoder() {
  use set_code <- decode.field(0, decode.string)
  use collector_number <- decode.field(1, decode.string)
  use quantity <- decode.field(2, decode.int)
  decode.success(#(set_code, collector_number, quantity))
}

pub fn latest_snapshot_rows() -> Result(List(SnapshotRowTuple), String) {
  sqlite_store.query(
    "WITH latest_succeeded AS ("
      <> "  SELECT id FROM import_runs"
      <> "  WHERE status = 'succeeded'"
      <> "  ORDER BY updated_at DESC, created_at DESC, rowid DESC"
      <> "  LIMIT 1"
      <> ") "
      <> "SELECT s.set_code, s.collector_number, SUM(s.quantity) "
      <> "FROM collection_snapshot s "
      <> "JOIN latest_succeeded ls ON s.import_run_id = ls.id "
      <> "GROUP BY s.set_code, s.collector_number;",
    [],
    snapshot_row_decoder(),
  )
  |> result.map_error(fn(error) { error.message })
}

pub fn replace_rows(
  import_run_id: String,
  rows: List(SnapshotRowTuple),
) -> Result(Nil, String) {
  use _ <- result.try(
    sqlite_store.exec(
      "DELETE FROM collection_snapshot WHERE import_run_id = ?;",
      [sqlight.text(import_run_id)],
    )
    |> result.map_error(fn(error) { error.message }),
  )
  insert_rows(import_run_id, rows)
}

fn insert_rows(
  import_run_id: String,
  rows: List(SnapshotRowTuple),
) -> Result(Nil, String) {
  let indexed = list.index_map(rows, fn(row, i) { #(row, i + 1) })
  indexed
  |> list.sized_chunk(insert_batch_size)
  |> list.try_each(insert_batch(import_run_id, _))
}

fn insert_batch(
  import_run_id: String,
  batch: List(#(SnapshotRowTuple, Int)),
) -> Result(Nil, String) {
  let placeholders =
    batch
    |> list.map(fn(_) { "(?, ?, ?, ?, ?, 'nonfoil', 'en', ?)" })
    |> string.join(", ")
  let params =
    batch
    |> list.flat_map(fn(pair) {
      let #(#(set_code, collector_number, quantity), row_number) = pair
      let row_id = import_run_id <> "-row-" <> int.to_string(row_number)
      [
        sqlight.text(row_id),
        sqlight.text(import_run_id),
        sqlight.int(row_number),
        sqlight.text(set_code),
        sqlight.text(collector_number),
        sqlight.int(quantity),
      ]
    })
  let sql =
    "INSERT INTO collection_snapshot ("
    <> "  id, import_run_id, row_number, set_code, collector_number, finish, language, quantity"
    <> ") VALUES "
    <> placeholders
    <> ";"
  sqlite_store.exec(sql, params)
  |> result.map_error(fn(error) { error.message })
}
