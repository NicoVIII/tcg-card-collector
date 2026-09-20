import collection/infrastructure/daos/collection_dao
import support/test_db

// Every row backfills to nonfoil/en per ADR 0010 — there is no unknown case,
// a re-import corrects the values. Quantities and keys must be untouched.
pub fn upgrade_preserves_every_row_test() {
  use <- test_db.with_seeded_upgrade("0016_collection_copy_key")

  assert collection_dao.list_cards()
    == Ok([
      collection_dao.CardRow("lea", "1", "nonfoil", "en", 1),
      collection_dao.CardRow("lea", "2", "nonfoil", "en", 4),
      collection_dao.CardRow("dsk", "104a", "nonfoil", "en", 2),
    ])
}
