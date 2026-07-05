import collection/infrastructure/daos/collection_dao
import gleam/dynamic/decode
import shared/infrastructure/stores/sqlite_store
import support/test_db

type CardRow =
  #(String, String, Int)

fn card_row_decoder() {
  use set_code <- decode.field(0, decode.string)
  use collector_number <- decode.field(1, decode.string)
  use quantity <- decode.field(2, decode.int)
  decode.success(#(set_code, collector_number, quantity))
}

fn rows_in(table: String) -> List(CardRow) {
  let assert Ok(rows) =
    sqlite_store.query(
      "SELECT set_code, collector_number, quantity FROM "
        <> table
        <> " ORDER BY set_code, collector_number;",
      [],
      card_row_decoder(),
    )
  rows
}

pub fn upsert_inserts_new_keys_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) =
    collection_dao.upsert_cards([#("lea", "1", 4), #("lea", "2", 1)])

  assert collection_dao.list_cards() == Ok([#("lea", "1", 4), #("lea", "2", 1)])
}

pub fn upsert_sums_into_existing_keys_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = collection_dao.upsert_cards([#("lea", "1", 4)])
  let assert Ok(Nil) =
    collection_dao.upsert_cards([#("lea", "1", 3), #("lea", "2", 1)])

  assert collection_dao.list_cards() == Ok([#("lea", "1", 7), #("lea", "2", 1)])
}

pub fn replace_truncates_and_refills_collection_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = collection_dao.upsert_cards([#("lea", "1", 4)])
  let assert Ok(Nil) = collection_dao.replace_collection([#("blb", "9", 1)])

  assert rows_in("collection") == [#("blb", "9", 1)]
}

pub fn list_cards_orders_by_key_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) =
    collection_dao.replace_collection([
      #("lea", "2", 1),
      #("blb", "9", 3),
      #("lea", "1", 4),
    ])

  assert collection_dao.list_cards()
    == Ok([#("blb", "9", 3), #("lea", "1", 4), #("lea", "2", 1)])
}
