import gleam/option.{None, Some}
import inventory_planning/infrastructure/daos/bulk_spec_dao
import inventory_planning/infrastructure/daos/inventory_rules_dao
import inventory_planning/infrastructure/daos/managed_locations_dao
import inventory_planning/infrastructure/daos/placed_cards_dao
import inventory_planning/infrastructure/daos/plan_dao
import support/test_db

fn a_rule(id: String) -> inventory_rules_dao.RuleRow {
  inventory_rules_dao.RuleRow(
    id:,
    location_name: "Binder",
    expression: "set_code in (a)",
    position: 0,
    selector: "all",
    sort_keys: "",
  )
}

fn a_placed_row(location: String) -> placed_cards_dao.PlacedCardRow {
  placed_cards_dao.PlacedCardRow(
    set_code: "mh2",
    collector_number: "17",
    finish: "foil",
    language: "en",
    location_kind: "cascade",
    location:,
    quantity: 1,
  )
}

pub fn replaces_every_present_table_at_once_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) =
    plan_dao.replace(
      Some([a_rule("rule-1")]),
      Some(#("Bulk", "name")),
      None,
      Some([a_placed_row("Box A")]),
    )

  assert inventory_rules_dao.list() == Ok([a_rule("rule-1")])
  assert bulk_spec_dao.get() == Ok(#("Bulk", "name"))
  assert placed_cards_dao.list() == Ok([a_placed_row("Box A")])
}

pub fn a_second_replace_clears_rows_the_new_call_leaves_out_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) =
    plan_dao.replace(Some([a_rule("rule-1")]), None, None, None)
  let assert Ok(Nil) =
    plan_dao.replace(Some([a_rule("rule-2")]), None, None, None)

  assert inventory_rules_dao.list() == Ok([a_rule("rule-2")])
}

pub fn none_leaves_that_table_untouched_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = inventory_rules_dao.upsert(a_rule("rule-1"))

  let assert Ok(Nil) =
    plan_dao.replace(None, Some(#("Bulk", "name")), None, None)

  assert inventory_rules_dao.list() == Ok([a_rule("rule-1")])
  assert bulk_spec_dao.get() == Ok(#("Bulk", "name"))
}

pub fn a_present_but_empty_list_clears_the_table_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = inventory_rules_dao.upsert(a_rule("rule-1"))

  let assert Ok(Nil) = plan_dao.replace(Some([]), None, None, None)

  assert inventory_rules_dao.list() == Ok([])
}

// Replacing the managed locations drops the ledger rows recorded at the old
// ones — their ids are gone — but leaves cascade rows alone when the ledger
// section itself isn't part of the restore.
pub fn replacing_managed_locations_drops_only_their_old_ledger_rows_test() {
  use _db <- test_db.with_temp_db()
  let assert Ok(Nil) =
    placed_cards_dao.increment([
      a_placed_row("Box A"),
      placed_cards_dao.PlacedCardRow(
        ..a_placed_row("old-deck"),
        location_kind: "managed",
      ),
    ])

  let assert Ok(Nil) =
    plan_dao.replace(
      None,
      None,
      Some(
        #(
          [managed_locations_dao.ManagedLocationRow("new-deck", "Burn", "deck")],
          [],
        ),
      ),
      None,
    )

  assert placed_cards_dao.list() == Ok([a_placed_row("Box A")])
  let assert Ok([deck]) = managed_locations_dao.load_all()
  assert deck.id == "new-deck"
}
