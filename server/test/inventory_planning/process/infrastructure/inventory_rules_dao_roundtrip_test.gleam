import inventory_planning/infrastructure/daos/inventory_rules_dao
import support/test_db

pub fn tab_and_quote_in_location_name_round_trips_test() {
  use _db <- test_db.with_temp_db()

  let tricky_name = "Box\t1's \"shelf\"\nrow"
  let assert Ok(Nil) =
    inventory_rules_dao.upsert(
      "rule-1",
      tricky_name,
      "set_code in (abc)",
      2,
      "first_per_oracle",
      "name,set_code",
    )

  let assert [
    #("rule-1", location_name, expression, position, selector, sort_keys),
  ] = inventory_rules_dao.list()
  assert location_name == tricky_name
  assert expression == "set_code in (abc)"
  assert position == 2
  assert selector == "first_per_oracle"
  assert sort_keys == "name,set_code"
}

pub fn rules_list_orders_by_position_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) =
    inventory_rules_dao.upsert("late", "Bulk", "set_code in (z)", 5, "all", "")
  let assert Ok(Nil) =
    inventory_rules_dao.upsert(
      "early",
      "Binder",
      "set_code in (a)",
      1,
      "all",
      "",
    )

  let assert [#("early", _, _, _, _, _), #("late", _, _, _, _, _)] =
    inventory_rules_dao.list()
}
