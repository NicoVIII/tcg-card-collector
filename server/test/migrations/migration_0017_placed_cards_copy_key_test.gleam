import inventory_planning/infrastructure/daos/placed_cards_dao
import support/test_db

// Every row backfills to nonfoil/en per ADR 0010. Two rows share
// (set_code, collector_number) across different locations — the pre-0017 PK
// allowed that — proving the rebuild doesn't collapse them via a GROUP BY.
pub fn upgrade_preserves_every_row_test() {
  use <- test_db.with_seeded_upgrade("0017_placed_cards_copy_key")

  assert placed_cards_dao.list()
    == Ok([
      placed_cards_dao.PlacedCardRow(
        "dsk",
        "104a",
        "nonfoil",
        "en",
        "Box B / Row 1",
        3,
      ),
      placed_cards_dao.PlacedCardRow(
        "lea",
        "1",
        "nonfoil",
        "en",
        "Box A / Row 1",
        1,
      ),
      placed_cards_dao.PlacedCardRow(
        "lea",
        "1",
        "nonfoil",
        "en",
        "Box A / Row 2",
        2,
      ),
    ])
}
