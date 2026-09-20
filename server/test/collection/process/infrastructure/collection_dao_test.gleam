import collection/infrastructure/daos/collection_dao
import gleam/dynamic/decode
import gleam/int
import gleam/list
import shared/infrastructure/stores/sqlite_store
import support/test_db

fn card_row_decoder() -> decode.Decoder(collection_dao.CardRow) {
  use set_code <- decode.field(0, decode.string)
  use collector_number <- decode.field(1, decode.string)
  use finish <- decode.field(2, decode.string)
  use language <- decode.field(3, decode.string)
  use quantity <- decode.field(4, decode.int)
  decode.success(collection_dao.CardRow(
    set_code:,
    collector_number:,
    finish:,
    language:,
    quantity:,
  ))
}

fn card(
  set_code: String,
  collector_number: String,
  quantity: Int,
) -> collection_dao.CardRow {
  collection_dao.CardRow(
    set_code:,
    collector_number:,
    finish: "nonfoil",
    language: "en",
    quantity:,
  )
}

fn copy(
  set_code: String,
  collector_number: String,
  finish: String,
  language: String,
  quantity: Int,
) -> collection_dao.CardRow {
  collection_dao.CardRow(
    set_code:,
    collector_number:,
    finish:,
    language:,
    quantity:,
  )
}

fn rows_in(table: String) -> List(collection_dao.CardRow) {
  let assert Ok(rows) =
    sqlite_store.query(
      "SELECT set_code, collector_number, finish, language, quantity FROM "
        <> table
        <> " ORDER BY set_code, collector_number, finish, language;",
      [],
      card_row_decoder(),
    )
  rows
}

pub fn upsert_inserts_new_keys_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) =
    collection_dao.upsert_cards([card("lea", "1", 4), card("lea", "2", 1)])

  assert collection_dao.list_cards()
    == Ok([card("lea", "1", 4), card("lea", "2", 1)])
}

pub fn upsert_sums_into_existing_keys_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = collection_dao.upsert_cards([card("lea", "1", 4)])
  let assert Ok(Nil) =
    collection_dao.upsert_cards([card("lea", "1", 3), card("lea", "2", 1)])

  assert collection_dao.list_cards()
    == Ok([card("lea", "1", 7), card("lea", "2", 1)])
}

// The primary key includes finish and language: a copy of the same printing
// in a different finish or language is a distinct row, not summed together.
pub fn upsert_keeps_different_finish_or_language_as_separate_rows_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) =
    collection_dao.upsert_cards([
      copy("m19", "85", "foil", "en", 1),
      copy("m19", "85", "nonfoil", "de", 1),
      copy("m19", "85", "nonfoil", "en", 2),
    ])

  assert collection_dao.list_cards()
    == Ok([
      copy("m19", "85", "foil", "en", 1),
      copy("m19", "85", "nonfoil", "de", 1),
      copy("m19", "85", "nonfoil", "en", 2),
    ])
}

pub fn replace_truncates_and_refills_collection_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = collection_dao.upsert_cards([card("lea", "1", 4)])
  let assert Ok(Nil) = collection_dao.replace_collection([card("blb", "9", 1)])

  assert rows_in("collection") == [card("blb", "9", 1)]
}

// Regression: a failed replace must not leave the collection empty (#44) —
// same shape as catalog_dao_replace_sets_test's failed_replace test. The
// primary key includes finish and language, so the two identical rows
// collide and the insert errors.
pub fn failed_replace_keeps_the_previous_collection_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = collection_dao.upsert_cards([card("lea", "1", 4)])

  let assert Error(_) =
    collection_dao.replace_collection([card("blb", "9", 1), card("blb", "9", 1)])

  assert collection_dao.list_cards() == Ok([card("lea", "1", 4)])
}

// Regression: upsert_cards chunks its inserts at 100 rows (#44) — a failure
// in a later chunk must not leave an earlier chunk's insert applied. 101
// rows forces two chunks; the CHECK (quantity > 0) rejects the row in the
// second chunk.
pub fn failed_add_leaves_the_collection_unchanged_test() {
  use _db <- test_db.with_temp_db()

  let valid_rows =
    list.repeat(Nil, 100)
    |> list.index_map(fn(_, i) { card("lea", int.to_string(i), 1) })
  let rows = list.append(valid_rows, [card("lea", "100", 0)])

  let assert Error(_) = collection_dao.upsert_cards(rows)

  assert collection_dao.list_cards() == Ok([])
}

pub fn decrement_subtracts_leaving_a_positive_remainder_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = collection_dao.upsert_cards([card("lea", "1", 4)])
  let assert Ok(Nil) = collection_dao.decrement_cards([card("lea", "1", 1)])

  assert collection_dao.list_cards() == Ok([card("lea", "1", 3)])
}

pub fn decrement_deletes_the_row_when_driven_to_zero_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = collection_dao.upsert_cards([card("lea", "1", 4)])
  let assert Ok(Nil) = collection_dao.decrement_cards([card("lea", "1", 4)])

  assert collection_dao.list_cards() == Ok([])
}

// The CHECK (quantity > 0) forbids a negative row, so an over-removal deletes
// the row outright rather than erroring — same clamp-to-zero-and-prune
// contract as placed_cards_dao.decrement.
pub fn decrement_deletes_the_row_when_the_removal_exceeds_owned_quantity_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = collection_dao.upsert_cards([card("lea", "1", 2)])
  let assert Ok(Nil) = collection_dao.decrement_cards([card("lea", "1", 5)])

  assert collection_dao.list_cards() == Ok([])
}

pub fn decrement_on_an_absent_key_is_a_no_op_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = collection_dao.decrement_cards([card("lea", "1", 1)])

  assert collection_dao.list_cards() == Ok([])
}
