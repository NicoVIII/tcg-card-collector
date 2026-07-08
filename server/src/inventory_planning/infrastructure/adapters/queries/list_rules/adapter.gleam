import gleam/list
import gleam/result
import inventory_planning/application/queries/list_rules/ports
import inventory_planning/infrastructure/daos/inventory_rules_dao

pub fn new() -> ports.ListInventoryRulesPort {
  ports.ListInventoryRulesPort(list_rules: fn() {
    use rows <- result.map(inventory_rules_dao.list())
    list.map(rows, fn(row) {
      let #(id, location_name, expression, position, selector, sort_keys) = row
      ports.InventoryRuleReadModel(
        id:,
        location_name:,
        expression:,
        position:,
        selector:,
        sort_keys:,
      )
    })
  })
}
