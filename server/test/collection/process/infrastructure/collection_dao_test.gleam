import collection/infrastructure/daos/collection_dao
import gleam/dynamic/decode
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
