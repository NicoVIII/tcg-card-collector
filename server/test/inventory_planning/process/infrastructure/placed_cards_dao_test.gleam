import inventory_planning/infrastructure/daos/placed_cards_dao
import support/test_db

pub fn increment_inserts_new_rows_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = placed_cards_dao.increment([#("lea", "1", "Binder", 2)])

  assert placed_cards_dao.list() == Ok([#("lea", "1", "Binder", 2)])
}

pub fn increment_sums_into_existing_key_and_location_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = placed_cards_dao.increment([#("lea", "1", "Binder", 2)])
  let assert Ok(Nil) = placed_cards_dao.increment([#("lea", "1", "Binder", 3)])

  assert placed_cards_dao.list() == Ok([#("lea", "1", "Binder", 5)])
}

pub fn same_key_in_two_locations_stays_separate_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) =
    placed_cards_dao.increment([
      #("lea", "1", "Binder", 1),
      #("lea", "1", "Bulk", 3),
    ])

  assert placed_cards_dao.list()
    == Ok([#("lea", "1", "Binder", 1), #("lea", "1", "Bulk", 3)])
}

pub fn decrement_reduces_quantity_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = placed_cards_dao.increment([#("lea", "1", "Bulk", 3)])
  let assert Ok(Nil) = placed_cards_dao.decrement([#("lea", "1", "Bulk", 1)])

  assert placed_cards_dao.list() == Ok([#("lea", "1", "Bulk", 2)])
}

pub fn mark_then_unmark_round_trip_deletes_the_row_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = placed_cards_dao.increment([#("lea", "1", "Bulk", 2)])
  let assert Ok(Nil) = placed_cards_dao.decrement([#("lea", "1", "Bulk", 2)])

  assert placed_cards_dao.list() == Ok([])
}

pub fn decrement_below_zero_prunes_the_row_without_going_negative_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = placed_cards_dao.increment([#("lea", "1", "Bulk", 2)])
  let assert Ok(Nil) = placed_cards_dao.decrement([#("lea", "1", "Bulk", 5)])

  assert placed_cards_dao.list() == Ok([])
}

pub fn decrementing_an_absent_row_is_a_no_op_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = placed_cards_dao.decrement([#("lea", "1", "Bulk", 1)])

  assert placed_cards_dao.list() == Ok([])
}

pub fn list_orders_by_key_then_location_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) =
    placed_cards_dao.increment([
      #("lea", "2", "Bulk", 1),
      #("lea", "1", "Bulk", 1),
      #("lea", "1", "Binder", 1),
    ])

  assert placed_cards_dao.list()
    == Ok([
      #("lea", "1", "Binder", 1),
      #("lea", "1", "Bulk", 1),
      #("lea", "2", "Bulk", 1),
    ])
}
