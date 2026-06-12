import application/queries/inventory_planning/list_rules/ports
import gleam/list
import infrastructure/stores/inventory_planning/inventory_rules_store

pub fn new() -> ports.ListInventoryRulesPort {
  ports.ListInventoryRulesPort(list_rules: fn() {
    inventory_rules_store.list()
    |> list.map(fn(row) {
      let #(id, location_name, expression) = row
      ports.InventoryRuleReadModel(id:, location_name:, expression:)
    })
  })
}
