import gleam/dynamic/decode
import gleam/list
import gleam/result
import gleam/string
import shared/infrastructure/stores/sqlite_store
import sqlight

pub type PlacedCardRow =
  #(String, String, String, Int)

const insert_batch_size = 100

fn placed_card_row_decoder() {
  use set_code <- decode.field(0, decode.string)
  use collector_number <- decode.field(1, decode.string)
  use location <- decode.field(2, decode.string)
  use quantity <- decode.field(3, decode.int)
  decode.success(#(set_code, collector_number, location, quantity))
}

pub fn list() -> Result(List(PlacedCardRow), String) {
  sqlite_store.query(
    "SELECT set_code, collector_number, location, quantity FROM placed_cards "
      <> "ORDER BY set_code, collector_number, location;",
    [],
    placed_card_row_decoder(),
  )
  |> result.map_error(fn(error) { error.message })
}

fn row_params(row: PlacedCardRow) -> List(sqlight.Value) {
  let #(set_code, collector_number, location, quantity) = row
  [
    sqlight.text(set_code),
    sqlight.text(collector_number),
    sqlight.text(location),
    sqlight.int(quantity),
  ]
}

// The writes below span several statements on separate connections
// (sqlite_store opens one per call), so they are not wrapped in a transaction.
// Acceptable for a single-user app: no concurrent writer can interleave.

fn increment_batch(batch: List(PlacedCardRow)) -> Result(Nil, String) {
  let placeholders =
    batch
    |> list.map(fn(_) { "(?, ?, ?, ?)" })
    |> string.join(", ")
  let params = list.flat_map(batch, row_params)
  let sql =
    "INSERT INTO placed_cards (set_code, collector_number, location, quantity) "
    <> "VALUES "
    <> placeholders
    <> " ON CONFLICT(set_code, collector_number, location) "
    <> "DO UPDATE SET quantity = quantity + excluded.quantity;"
  sqlite_store.exec(sql, params)
  |> result.map_error(fn(error) { error.message })
}

/// Adds each row's quantity onto the matching (key, location), inserting the
/// row when it is absent.
pub fn increment(rows: List(PlacedCardRow)) -> Result(Nil, String) {
  rows
  |> list.sized_chunk(insert_batch_size)
  |> list.try_each(increment_batch)
}

// The CHECK (quantity > 0) forbids ever writing a non-positive row, so a row
// the decrement would drive to zero or below is deleted outright rather than
// updated; only rows that stay positive are decremented.
fn decrement_row(row: PlacedCardRow) -> Result(Nil, String) {
  let #(set_code, collector_number, location, quantity) = row
  let where_key =
    " WHERE set_code = ? AND collector_number = ? AND location = ?"
  let key_params = [
    sqlight.text(set_code),
    sqlight.text(collector_number),
    sqlight.text(location),
  ]

  use _ <- result.try(
    sqlite_store.exec(
      "DELETE FROM placed_cards" <> where_key <> " AND quantity <= ?;",
      list.append(key_params, [sqlight.int(quantity)]),
    )
    |> result.map_error(fn(error) { error.message }),
  )
  sqlite_store.exec(
    "UPDATE placed_cards SET quantity = quantity - ?"
      <> where_key
      <> " AND quantity > ?;",
    list.flatten([[sqlight.int(quantity)], key_params, [sqlight.int(quantity)]]),
  )
  |> result.map_error(fn(error) { error.message })
}

/// Subtracts each row's quantity from the matching (key, location), pruning any
/// row driven to zero or below. Decrementing an absent row is a no-op.
pub fn decrement(rows: List(PlacedCardRow)) -> Result(Nil, String) {
  list.try_each(rows, decrement_row)
}
