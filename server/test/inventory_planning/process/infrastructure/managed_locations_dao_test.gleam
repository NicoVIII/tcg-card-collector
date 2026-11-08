import gleam/dict
import inventory_planning/domain/managed_location.{Deck, ManagedLocation}
import inventory_planning/infrastructure/daos/managed_locations_dao.{
  type MemberRow, ManagedLocationRow, MemberRow,
}
import inventory_planning/infrastructure/daos/placed_cards_dao.{PlacedCardRow}
import shared/domain/copy_key
import support/test_db

fn member(id: String, collector_number: String, quantity: Int) -> MemberRow {
  MemberRow(
    managed_location_id: id,
    set_code: "lea",
    collector_number:,
    finish: "nonfoil",
    language: "en",
    quantity:,
  )
}

fn key(collector_number: String) -> copy_key.CopyKey {
  let assert Ok(key) =
    copy_key.new(
      set_code: "lea",
      collector_number:,
      finish: "nonfoil",
      language: "en",
    )
  key
}

pub fn load_all_assembles_each_location_with_its_own_members_test() {
  use _db <- test_db.with_temp_db()
  let assert Ok(Nil) =
    managed_locations_dao.insert(ManagedLocationRow("d1", "Mono-Red", "deck"))
  let assert Ok(Nil) =
    managed_locations_dao.insert(ManagedLocationRow("d2", "Elves", "deck"))
  let assert Ok(Nil) =
    managed_locations_dao.increment_members([
      member("d1", "1", 2),
      member("d1", "1", 1),
      member("d2", "2", 1),
    ])

  assert managed_locations_dao.load_all()
    == Ok([
      ManagedLocation("d2", "Elves", Deck, dict.from_list([#(key("2"), 1)])),
      ManagedLocation("d1", "Mono-Red", Deck, dict.from_list([#(key("1"), 3)])),
    ])
}

pub fn decrement_members_prunes_a_member_driven_to_zero_test() {
  use _db <- test_db.with_temp_db()
  let assert Ok(Nil) =
    managed_locations_dao.insert(ManagedLocationRow("d1", "Mono-Red", "deck"))
  let assert Ok(Nil) =
    managed_locations_dao.increment_members([
      member("d1", "1", 2),
      member("d1", "2", 1),
    ])

  let assert Ok(Nil) =
    managed_locations_dao.decrement_members([
      member("d1", "1", 1),
      member("d1", "2", 1),
    ])

  assert managed_locations_dao.list_members() == Ok([member("d1", "1", 1)])
}

pub fn the_database_rejects_a_second_location_with_the_same_name_test() {
  use _db <- test_db.with_temp_db()
  let assert Ok(Nil) =
    managed_locations_dao.insert(ManagedLocationRow("d1", "Mono-Red", "deck"))

  let assert Error(_) =
    managed_locations_dao.insert(ManagedLocationRow("d2", "Mono-Red", "deck"))
}

// Deleting a deck takes its members and its ledger rows with it — and only
// its own: a cascade location whose name happens to equal the deck's id keeps
// its rows, since the two namespaces never share a ledger row.
pub fn delete_removes_members_and_only_its_own_ledger_rows_test() {
  use _db <- test_db.with_temp_db()
  let assert Ok(Nil) =
    managed_locations_dao.insert(ManagedLocationRow("d1", "Mono-Red", "deck"))
  let assert Ok(Nil) =
    managed_locations_dao.increment_members([member("d1", "1", 1)])
  let assert Ok(Nil) =
    placed_cards_dao.increment([
      PlacedCardRow("lea", "1", "nonfoil", "en", "managed", "d1", 1),
      PlacedCardRow("lea", "1", "nonfoil", "en", "cascade", "d1", 2),
    ])

  let assert Ok(Nil) = managed_locations_dao.delete("d1")

  assert managed_locations_dao.load_all() == Ok([])
  assert managed_locations_dao.list_members() == Ok([])
  assert placed_cards_dao.list()
    == Ok([PlacedCardRow("lea", "1", "nonfoil", "en", "cascade", "d1", 2)])
}
