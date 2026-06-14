import gleam/list
import inventory_planning/application/queries/list_rules/ports
import inventory_planning/infrastructure/stores/inventory_rules_store

pub fn new() -> ports.ListInventoryRulesPort {
  ports.ListInventoryRulesPort(list_rules: fn() {
    inventory_rules_store.list()
    |> list.map(fn(row) {
      let #(id, location_name, expression) = row
      ports.InventoryRuleReadModel(id:, location_name:, expression:)
    })
  })
}
