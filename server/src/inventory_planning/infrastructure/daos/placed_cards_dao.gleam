import gleam/dynamic/decode
import gleam/list
import shared/infrastructure/stores/sqlite_store
import sqlight

pub type PlacedCardRow {
  PlacedCardRow(
    set_code: String,
    collector_number: String,
    finish: String,
    language: String,
    // "cascade" or "managed" (migration 0021): `location` is a cascade
    // location's name or a managed location's id accordingly.
    location_kind: String,
    location: String,
    quantity: Int,
  )
}

const insert_batch_size = 100

fn placed_card_row_decoder() -> decode.Decoder(PlacedCardRow) {
  use set_code <- decode.field(0, decode.string)
  use collector_number <- decode.field(1, decode.string)
  use finish <- decode.field(2, decode.string)
  use language <- decode.field(3, decode.string)
  use location_kind <- decode.field(4, decode.string)
  use location <- decode.field(5, decode.string)
  use quantity <- decode.field(6, decode.int)
  decode.success(PlacedCardRow(
    set_code:,
    collector_number:,
    finish:,
    language:,
    location_kind:,
    location:,
    quantity:,
  ))
}

pub fn list() -> Result(List(PlacedCardRow), String) {
  sqlite_store.query(
    "SELECT set_code, collector_number, finish, language, location_kind, location, quantity "
      <> "FROM placed_cards "
      <> "ORDER BY set_code, collector_number, finish, language, location_kind, location;",
    [],
    placed_card_row_decoder(),
  )
}

fn row_params(row: PlacedCardRow) -> List(sqlight.Value) {
  [
    sqlight.text(row.set_code),
    sqlight.text(row.collector_number),
    sqlight.text(row.finish),
    sqlight.text(row.language),
    sqlight.text(row.location_kind),
    sqlight.text(row.location),
    sqlight.int(row.quantity),
  ]
}

fn increment_batch_statement(
  batch: List(PlacedCardRow),
) -> #(String, List(sqlight.Value)) {
  let placeholders =
    sqlite_store.placeholders(list.length(batch), "(?, ?, ?, ?, ?, ?, ?)")
  let params = list.flat_map(batch, row_params)
  let sql =
    "INSERT INTO placed_cards (set_code, collector_number, finish, language, location_kind, location, quantity) "
    <> "VALUES "
    <> placeholders
    <> " ON CONFLICT(set_code, collector_number, finish, language, location_kind, location) "
    <> "DO UPDATE SET quantity = quantity + excluded.quantity;"
  #(sql, params)
}

/// `increment`'s statements, for a caller composing them with other writes in
/// one `sqlite_store.exec_all_atomically`.
pub fn increment_statements(
  rows: List(PlacedCardRow),
) -> List(#(String, List(sqlight.Value))) {
  rows
  |> list.sized_chunk(insert_batch_size)
  |> list.map(increment_batch_statement)
}

/// Adds each row's quantity onto the matching (key, location), inserting the
/// row when it is absent.
pub fn increment(rows: List(PlacedCardRow)) -> Result(Nil, String) {
  increment_statements(rows)
  |> list.try_each(fn(statement) { sqlite_store.exec(statement.0, statement.1) })
}

// The CHECK (quantity > 0) forbids ever writing a non-positive row, so a row
// the decrement would drive to zero or below is deleted outright rather than
// updated; only rows that stay positive are decremented. The two statements
// are mutually exclusive by their own WHERE clauses, so listing both per row
// is safe to run unconditionally.
fn decrement_row_statements(
  row: PlacedCardRow,
) -> List(#(String, List(sqlight.Value))) {
  let PlacedCardRow(
    set_code:,
    collector_number:,
    finish:,
    language:,
    location_kind:,
    location:,
    quantity:,
  ) = row
  let where_key =
    " WHERE set_code = ? AND collector_number = ? AND finish = ? "
    <> "AND language = ? AND location_kind = ? AND location = ?"
  let key_params = [
    sqlight.text(set_code),
    sqlight.text(collector_number),
    sqlight.text(finish),
    sqlight.text(language),
    sqlight.text(location_kind),
    sqlight.text(location),
  ]

  [
    #(
      "DELETE FROM placed_cards" <> where_key <> " AND quantity <= ?;",
      list.append(key_params, [sqlight.int(quantity)]),
    ),
    #(
      "UPDATE placed_cards SET quantity = quantity - ?"
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

/// `decrement`'s statements, for a caller composing them with other writes in
/// one `sqlite_store.exec_all_atomically`.
pub fn decrement_statements(
  rows: List(PlacedCardRow),
) -> List(#(String, List(sqlight.Value))) {
  list.flat_map(rows, decrement_row_statements)
}

/// Subtracts each row's quantity from the matching (key, location), pruning any
/// row driven to zero or below, all in one transaction. Decrementing an absent
/// row is a no-op.
pub fn decrement(rows: List(PlacedCardRow)) -> Result(Nil, String) {
  sqlite_store.exec_all_atomically(decrement_statements(rows))
}

/// Moves every row at cascade location `from` onto cascade location `to`,
/// summing into any row already there — a rule-target rename's ledger fix
/// (#107): no copy of card physically moved, only the record of where it
/// sits. Managed locations never need this: their rows key on an id a rename
/// doesn't change. Caller guarantees `from != to` (domain `Relocation`), so
/// the INSERT...SELECT always completes before the DELETE removes its own
/// source rows.
pub fn relocate(from: String, to: String) -> Result(Nil, String) {
  let insert_sql =
    "INSERT INTO placed_cards (set_code, collector_number, finish, language, location_kind, location, quantity) "
    <> "SELECT set_code, collector_number, finish, language, 'cascade', ?, quantity "
    <> "FROM placed_cards WHERE location_kind = 'cascade' AND location = ? "
    <> "ON CONFLICT(set_code, collector_number, finish, language, location_kind, location) "
    <> "DO UPDATE SET quantity = quantity + excluded.quantity;"
  let delete_sql =
    "DELETE FROM placed_cards WHERE location_kind = 'cascade' AND location = ?;"

  sqlite_store.exec_all_atomically([
    #(insert_sql, [sqlight.text(to), sqlight.text(from)]),
    #(delete_sql, [sqlight.text(from)]),
  ])
}
