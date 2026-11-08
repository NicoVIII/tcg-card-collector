import inventory_planning/infrastructure/daos/placed_cards_dao.{PlacedCardRow}
import support/test_db

// Every pre-0021 row is a cascade location (managed locations didn't exist),
// so each backfills as 'cascade' with its location text untouched.
pub fn upgrade_backfills_every_row_as_a_cascade_location_test() {
  use <- test_db.with_seeded_upgrade("0021_placed_cards_location_kind")

  assert placed_cards_dao.list()
    == Ok([
      PlacedCardRow("dsk", "104a", "etched", "ja", "cascade", "Bulk", 3),
      PlacedCardRow("lea", "1", "foil", "de", "cascade", "Box A / Row 2", 1),
      PlacedCardRow("lea", "1", "nonfoil", "en", "cascade", "Box A / Row 1", 1),
      PlacedCardRow("lea", "1", "nonfoil", "en", "cascade", "Box A / Row 2", 2),
    ])
}
