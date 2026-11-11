import portability/domain/export_document.{BulkSpec, Rule}
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
  assert ports.check_rule(Rule(
      location: " ",
      expression: "rarity >= rare",
      selector: "all",
      sort_keys: "",
    ))
    == Error("location name is blank")
}

pub fn check_bulk_spec_delegates_to_inventory_plannings_own_parsers_test() {
  let ports = adapter.new()

  assert ports.check_bulk_spec(BulkSpec(location: "Bulk", sort_keys: "name"))
    == Ok(Nil)
  assert ports.check_bulk_spec(BulkSpec(location: "Bulk", sort_keys: "power"))
    != Ok(Nil)
  assert ports.check_bulk_spec(BulkSpec(location: "  ", sort_keys: "name"))
    != Ok(Nil)
}
