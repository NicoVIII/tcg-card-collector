import portability/domain/export_document.{Rule}
import portability/infrastructure/adapters/queries/preview_import/adapter

pub fn check_rule_delegates_to_inventory_plannings_own_parsers_test() {
  let ports = adapter.new()

  assert ports.check_rule(Rule(
      location: "Binder A",
      expression: "rarity >= rare",
      selector: "all",
      sort_keys: "",
    ))
    == Ok(Nil)
  assert ports.check_rule(Rule(
      location: "Binder A",
      expression: "not a real predicate",
      selector: "all",
      sort_keys: "",
    ))
    != Ok(Nil)
}

pub fn check_sort_keys_delegates_to_inventory_plannings_own_parser_test() {
  let ports = adapter.new()

  assert ports.check_sort_keys("name,set_code") == Ok(Nil)
  assert ports.check_sort_keys("power") != Ok(Nil)
}
