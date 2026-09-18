import gleam/list
import inventory_planning/application/commands/reorder_rules/ports
import inventory_planning/infrastructure/daos/inventory_rules_dao

pub fn new() -> ports.ReorderInventoryRulesPorts {
  ports.ReorderInventoryRulesPorts(
    list_rule_ids: inventory_rules_dao.list_ids,
    set_positions: fn(positions) {
      inventory_rules_dao.set_positions(
        list.map(positions, fn(position) {
          inventory_rules_dao.RulePositionRow(
            id: position.id,
            position: position.position,
          )
        }),
      )
    },
  )
}
