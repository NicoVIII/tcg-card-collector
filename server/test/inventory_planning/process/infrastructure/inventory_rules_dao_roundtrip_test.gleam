import inventory_planning/infrastructure/daos/inventory_rules_dao
import support/test_db

pub fn tab_and_quote_in_location_name_round_trips_test() {
  use _db <- test_db.with_temp_db()

  let tricky_name = "Box\t1's \"shelf\"\nrow"
  let assert Ok(Nil) =
    inventory_rules_dao.upsert("rule-1", tricky_name, "set_code=abc")

  let assert [#("rule-1", location_name, "set_code=abc")] =
    inventory_rules_dao.list()
  assert location_name == tricky_name
}
