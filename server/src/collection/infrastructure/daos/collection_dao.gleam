import gleam/dynamic/decode
import gleam/list
import shared/infrastructure/stores/sqlite_store
import sqlight

pub type CardRow {
  CardRow(
    set_code: String,
    collector_number: String,
    finish: String,
    language: String,
    quantity: Int,
  )
}

const insert_batch_size = 100

fn card_row_decoder() -> decode.Decoder(CardRow) {
  use set_code <- decode.field(0, decode.string)
  use collector_number <- decode.field(1, decode.string)
  use finish <- decode.field(2, decode.string)
  use language <- decode.field(3, decode.string)
  use quantity <- decode.field(4, decode.int)
  decode.success(CardRow(
    set_code:,
    collector_number:,
    finish:,
    language:,
    quantity:,
  ))
}

// Unordered: a TEXT ORDER BY can't express the numeric-aware collector-number
// order the grid needs, so the list_cards query sorts the rows in the app layer.
pub fn list_cards() -> Result(List(CardRow), String) {
  sqlite_store.query(
    "SELECT set_code, collector_number, finish, language, quantity FROM collection;",
    [],
    card_row_decoder(),
  )
}

fn batch_values(batch: List(CardRow)) -> #(String, List(sqlight.Value)) {
  let placeholders =
    sqlite_store.placeholders(list.length(batch), "(?, ?, ?, ?, ?)")
  let params =
    batch
    |> list.flat_map(fn(row: CardRow) {
      [
        sqlight.text(row.set_code),
        sqlight.text(row.collector_number),
        sqlight.text(row.finish),
        sqlight.text(row.language),
        sqlight.int(row.quantity),
      ]
    })
  #(placeholders, params)
}

fn insert_statement(
  suffix: String,
  batch: List(CardRow),
) -> #(String, List(sqlight.Value)) {
  let #(placeholders, params) = batch_values(batch)
  let sql =
    "INSERT INTO collection (set_code, collector_number, finish, language, quantity) VALUES "
    <> placeholders
    <> suffix
  #(sql, params)
}

fn insert_statements(
  rows: List(CardRow),
) -> List(#(String, List(sqlight.Value))) {
  rows
  |> list.sized_chunk(insert_batch_size)
  |> list.map(insert_statement(";", _))
}

fn upsert_statements(
  rows: List(CardRow),
) -> List(#(String, List(sqlight.Value))) {
  let suffix =
    " ON CONFLICT(set_code, collector_number, finish, language) "
    <> "DO UPDATE SET quantity = quantity + excluded.quantity;"
  rows
  |> list.sized_chunk(insert_batch_size)
  |> list.map(insert_statement(suffix, _))
}

// The CHECK (quantity > 0) forbids ever writing a non-positive row, so a row
// the decrement would drive to zero or below is deleted outright rather than
// updated; only rows that stay positive are decremented. The two statements
// are mutually exclusive by their own WHERE clauses, so listing both per row
// is safe to run unconditionally. Mirrors placed_cards_dao's decrement.
fn decrement_row_statements(
  row: CardRow,
) -> List(#(String, List(sqlight.Value))) {
  let CardRow(set_code:, collector_number:, finish:, language:, quantity:) = row
  let where_key =
    " WHERE set_code = ? AND collector_number = ? AND finish = ? AND language = ?"
  let key_params = [
    sqlight.text(set_code),
    sqlight.text(collector_number),
    sqlight.text(finish),
    sqlight.text(language),
  ]

  [
    #(
      "DELETE FROM collection" <> where_key <> " AND quantity <= ?;",
      list.append(key_params, [sqlight.int(quantity)]),
    ),
    #(
      "UPDATE collection SET quantity = quantity - ?"
        <> where_key
        <> " AND quantity > ?;",
      list.flatten([
        [sqlight.int(quantity)],
        key_params,
        [sqlight.int(quantity)],
      ]),
    ),
  ]
}

/// An import states the whole collection: truncate the collection, then refill
/// it, all in one transaction — a failed refill must not leave the
/// collection empty. Placement state lives in inventory planning and
/// derives from here.
pub fn replace_collection(rows: List(CardRow)) -> Result(Nil, String) {
  sqlite_store.exec_all_atomically([
    #("DELETE FROM collection;", []),
    ..insert_statements(rows)
  ])
}

/// An add grows the collection, summing each row's quantity into the existing
/// key, all in one transaction — a failure partway through must not leave a
/// partial add applied. Whether the new copies are physically placed is
/// inventory planning's concern, derived from the collection rather than
/// tracked here.
pub fn upsert_cards(rows: List(CardRow)) -> Result(Nil, String) {
  sqlite_store.exec_all_atomically(upsert_statements(rows))
}

/// A remove shrinks the collection, subtracting each row's quantity from the
/// matching key, pruning any row driven to zero or below, all in one
/// transaction. Decrementing an absent key is a no-op. Whether the shrink
/// leaves the placed ledger claiming more copies than are owned is Inventory
/// Planning's concern, reconciled via ADR 0011's event bus rather than here.
pub fn decrement_cards(rows: List(CardRow)) -> Result(Nil, String) {
  sqlite_store.exec_all_atomically(list.flat_map(rows, decrement_row_statements))
}
