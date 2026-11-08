import gleam/dynamic/decode
import shared/infrastructure/stores/sqlite_store
import support/test_db

// Read with 0021's own columns rather than through placed_cards_dao: the
// DAO tracks the current schema, so a later reshape of `placed_cards` would
// break this frozen test.
fn list_rows() -> Result(
  List(#(String, String, String, String, String, String, Int)),
  String,
) {
  sqlite_store.query(
    "SELECT set_code, collector_number, finish, language, location_kind, location, quantity "
      <> "FROM placed_cards "
      <> "ORDER BY set_code, collector_number, finish, language, location_kind, location;",
    [],
    {
      use set_code <- decode.field(0, decode.string)
      use collector_number <- decode.field(1, decode.string)
      use finish <- decode.field(2, decode.string)
      use language <- decode.field(3, decode.string)
      use location_kind <- decode.field(4, decode.string)
      use location <- decode.field(5, decode.string)
      use quantity <- decode.field(6, decode.int)
      decode.success(#(
        set_code,
        collector_number,
        finish,
        language,
        location_kind,
        location,
        quantity,
      ))
    },
  )
}

// Every pre-0021 row is a cascade location (managed locations didn't exist),
// so each backfills as 'cascade' with its location text untouched.
pub fn upgrade_backfills_every_row_as_a_cascade_location_test() {
  use <- test_db.with_seeded_upgrade("0021_placed_cards_location_kind")

  assert list_rows()
    == Ok([
      #("dsk", "104a", "etched", "ja", "cascade", "Bulk", 3),
      #("lea", "1", "foil", "de", "cascade", "Box A / Row 2", 1),
      #("lea", "1", "nonfoil", "en", "cascade", "Box A / Row 1", 1),
      #("lea", "1", "nonfoil", "en", "cascade", "Box A / Row 2", 2),
    ])
}
