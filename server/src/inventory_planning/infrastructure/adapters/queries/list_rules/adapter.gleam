import gleam/list
import inventory_planning/application/queries/list_rules/ports
import inventory_planning/infrastructure/daos/inventory_rules_dao

pub fn new() -> ports.ListInventoryRulesPort {
  ports.ListInventoryRulesPort(list_rules: fn() {
    inventory_rules_dao.list()
    |> list.map(fn(row) {
      let #(id, location_name, expression, position, selector) = row
      ports.InventoryRuleReadModel(
        id:,
        location_name:,
        expression:,
        position:,
        selector:,
      )
    })
  })
}
