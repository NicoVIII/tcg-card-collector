import gleam/dynamic/decode
import gleam/list
import gleam/result
import gleam/string
import shared/infrastructure/stores/sqlite_store
import sqlight

type CardRow =
  #(String, String, Int)

const insert_batch_size = 100

fn card_row_decoder() {
  use set_code <- decode.field(0, decode.string)
  use collector_number <- decode.field(1, decode.string)
  use quantity <- decode.field(2, decode.int)
  decode.success(#(set_code, collector_number, quantity))
}

pub fn list_cards() -> Result(List(CardRow), String) {
  sqlite_store.query(
    "SELECT set_code, collector_number, quantity FROM collection "
      <> "ORDER BY set_code, collector_number;",
    [],
    card_row_decoder(),
  )
  |> result.map_error(fn(error) { error.message })
}

fn batch_values(batch: List(CardRow)) -> #(String, List(sqlight.Value)) {
  let placeholders =
    batch
    |> list.map(fn(_) { "(?, ?, ?)" })
    |> string.join(", ")
  let params =
    batch
    |> list.flat_map(fn(row) {
      let #(set_code, collector_number, quantity) = row
      [
        sqlight.text(set_code),
        sqlight.text(collector_number),
        sqlight.int(quantity),
      ]
    })
  #(placeholders, params)
}

fn exec_batch(
  table: String,
  suffix: String,
  batch: List(CardRow),
) -> Result(Nil, String) {
  let #(placeholders, params) = batch_values(batch)
  let sql =
    "INSERT INTO "
    <> table
    <> " (set_code, collector_number, quantity) VALUES "
    <> placeholders
    <> suffix
  sqlite_store.exec(sql, params)
  |> result.map_error(fn(error) { error.message })
}

fn insert_rows(table: String, rows: List(CardRow)) -> Result(Nil, String) {
  rows
  |> list.sized_chunk(insert_batch_size)
  |> list.try_each(exec_batch(table, ";", _))
}

fn upsert_rows(table: String, rows: List(CardRow)) -> Result(Nil, String) {
  let suffix =
    " ON CONFLICT(set_code, collector_number) "
    <> "DO UPDATE SET quantity = quantity + excluded.quantity;"
  rows
  |> list.sized_chunk(insert_batch_size)
  |> list.try_each(exec_batch(table, suffix, _))
}

fn delete_all(table: String) -> Result(Nil, String) {
  sqlite_store.exec("DELETE FROM " <> table <> ";", [])
  |> result.map_error(fn(error) { error.message })
}

// The writes below span several statements on separate connections
// (sqlite_store opens one per call), so they are not wrapped in a transaction.
// Acceptable for a single-user app: no concurrent writer can interleave, and a
// mid-write failure surfaces as an error the calling handler reports.

/// An import states the whole collection: truncate the collection, then refill
/// it. Placement state lives in inventory planning and derives from here.
pub fn replace_collection(rows: List(CardRow)) -> Result(Nil, String) {
  use _ <- result.try(delete_all("collection"))
  insert_rows("collection", rows)
}

/// An add grows the collection, summing each row's quantity into the existing
/// key. Whether the new copies are physically placed is inventory planning's
/// concern, derived from the collection rather than tracked here.
pub fn upsert_cards(rows: List(CardRow)) -> Result(Nil, String) {
  upsert_rows("collection", rows)
}
