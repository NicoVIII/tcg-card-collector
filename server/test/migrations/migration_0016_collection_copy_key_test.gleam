import gleam/dynamic/decode
import shared/infrastructure/stores/sqlite_store
import support/test_db

// Read with 0016's own columns rather than through collection_dao: the DAO
// tracks the current schema, so a later reshape of `collection` would break
// this frozen test.
fn list_rows() -> Result(List(#(String, String, String, String, Int)), String) {
  sqlite_store.query(
    "SELECT set_code, collector_number, finish, language, quantity FROM collection;",
    [],
    {
      use set_code <- decode.field(0, decode.string)
      use collector_number <- decode.field(1, decode.string)
      use finish <- decode.field(2, decode.string)
      use language <- decode.field(3, decode.string)
      use quantity <- decode.field(4, decode.int)
      decode.success(#(set_code, collector_number, finish, language, quantity))
    },
  )
}

// Every row backfills to nonfoil/en per ADR 0010 — there is no unknown case,
// a re-import corrects the values. Quantities and keys must be untouched.
pub fn upgrade_preserves_every_row_test() {
  use <- test_db.with_seeded_upgrade("0016_collection_copy_key")

  assert list_rows()
    == Ok([
      #("lea", "1", "nonfoil", "en", 1),
      #("lea", "2", "nonfoil", "en", 4),
      #("dsk", "104a", "nonfoil", "en", 2),
    ])
}
