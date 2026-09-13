import gleam/list
import gleam/result
import inventory_planning/application/queries/list_rules/ports
import inventory_planning/infrastructure/daos/inventory_rules_dao

pub fn new() -> ports.ListInventoryRulesPort {
  ports.ListInventoryRulesPort(list_rules: fn() {
    use rows <- result.map(inventory_rules_dao.list())
    list.map(rows, fn(row) {
      ports.InventoryRuleReadModel(
        id: row.id,
        location_name: row.location_name,
        expression: row.expression,
        position: row.position,
        selector: row.selector,
        sort_keys: row.sort_keys,
      )
    })
  })
}
