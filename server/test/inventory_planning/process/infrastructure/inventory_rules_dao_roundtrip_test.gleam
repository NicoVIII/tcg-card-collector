import inventory_planning/infrastructure/daos/inventory_rules_dao
import support/test_db

fn rule(id: String, position: Int) -> inventory_rules_dao.RuleRow {
  inventory_rules_dao.RuleRow(
    id:,
    location_name: "Binder",
    expression: "set_code in (a)",
    position:,
    selector: "all",
    sort_keys: "",
  )
}

pub fn tab_and_quote_in_location_name_round_trips_test() {
  use _db <- test_db.with_temp_db()

  let tricky_name = "Box\t1's \"shelf\"\nrow"
  let assert Ok(Nil) =
    inventory_rules_dao.upsert(inventory_rules_dao.RuleRow(
      id: "rule-1",
      location_name: tricky_name,
      expression: "set_code in (abc)",
      position: 2,
      selector: "first_per_oracle",
      sort_keys: "name,set_code",
    ))

  let assert Ok([rule]) = inventory_rules_dao.list()
  assert rule
    == inventory_rules_dao.RuleRow(
      id: "rule-1",
      location_name: tricky_name,
      expression: "set_code in (abc)",
      position: 2,
      selector: "first_per_oracle",
      sort_keys: "name,set_code",
    )
}

pub fn rules_list_orders_by_position_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = inventory_rules_dao.upsert(rule("late", 5))
  let assert Ok(Nil) = inventory_rules_dao.upsert(rule("early", 1))

  let assert Ok([early, late]) = inventory_rules_dao.list()
  assert early.id == "early"
  assert late.id == "late"
}

pub fn list_ids_orders_by_position_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = inventory_rules_dao.upsert(rule("late", 5))
  let assert Ok(Nil) = inventory_rules_dao.upsert(rule("early", 1))

  let assert Ok(ids) = inventory_rules_dao.list_ids()
  assert ids == ["early", "late"]
}

pub fn set_positions_renumbers_every_row_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = inventory_rules_dao.upsert(rule("a", 0))
  let assert Ok(Nil) = inventory_rules_dao.upsert(rule("b", 1))

  let assert Ok(Nil) =
    inventory_rules_dao.set_positions([
      inventory_rules_dao.RulePositionRow(id: "b", position: 0),
      inventory_rules_dao.RulePositionRow(id: "a", position: 1),
    ])

  let assert Ok([first, second]) = inventory_rules_dao.list()
  assert first.id == "b"
  assert second.id == "a"
}
