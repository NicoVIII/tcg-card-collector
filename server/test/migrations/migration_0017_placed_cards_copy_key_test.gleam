import gleam/dynamic/decode
import shared/infrastructure/stores/sqlite_store
import support/test_db

// Read with 0017's own columns rather than through placed_cards_dao: the
// DAO tracks the current schema, which gained location_kind in 0021.
fn list_rows() -> Result(
  List(#(String, String, String, String, String, Int)),
  String,
) {
  sqlite_store.query(
    "SELECT set_code, collector_number, finish, language, location, quantity "
      <> "FROM placed_cards "
      <> "ORDER BY set_code, collector_number, finish, language, location;",
    [],
    {
      use set_code <- decode.field(0, decode.string)
      use collector_number <- decode.field(1, decode.string)
      use finish <- decode.field(2, decode.string)
      use language <- decode.field(3, decode.string)
      use location <- decode.field(4, decode.string)
      use quantity <- decode.field(5, decode.int)
      decode.success(#(
        set_code,
        collector_number,
        finish,
        language,
        location,
        quantity,
      ))
    },
  )
}

// Every row backfills to nonfoil/en per ADR 0010. Two rows share
// (set_code, collector_number) across different locations — the pre-0017 PK
// allowed that — proving the rebuild doesn't collapse them via a GROUP BY.
pub fn upgrade_preserves_every_row_test() {
  use <- test_db.with_seeded_upgrade("0017_placed_cards_copy_key")

  assert list_rows()
    == Ok([
      #("dsk", "104a", "nonfoil", "en", "Box B / Row 1", 3),
      #("lea", "1", "nonfoil", "en", "Box A / Row 1", 1),
      #("lea", "1", "nonfoil", "en", "Box A / Row 2", 2),
    ])
}
