import gleam/dynamic/decode
import shared/infrastructure/stores/sqlite_store
import support/test_db

// Read with 0023's own columns rather than through insights_dao: the DAO
// tracks the current schema, so a later reshape of `target_sets` would break
// this frozen test.
fn list_rows() -> Result(List(#(String, String)), String) {
  sqlite_store.query(
    "SELECT set_code, created_at FROM target_sets ORDER BY set_code;",
    [],
    {
      use set_code <- decode.field(0, decode.string)
      use created_at <- decode.field(1, decode.string)
      decode.success(#(set_code, created_at))
    },
  )
}

pub fn upgrade_canonicalises_codes_and_keeps_the_earliest_mark_test() {
  use <- test_db.with_seeded_upgrade("0023_canonical_target_sets")

  assert list_rows()
    == Ok([
      #("grn", "2026-01-01T00:00:00Z"),
      #("lea", "2026-05-01T00:00:00Z"),
      #("m11", "2026-04-01T00:00:00Z"),
    ])
}
