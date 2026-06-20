import inventory_planning/application/commands/delete_rule/ports
import inventory_planning/infrastructure/daos/inventory_rules_dao

pub fn new() -> ports.DeleteInventoryRulePort {
  ports.DeleteInventoryRulePort(delete_rule: fn(rule_id) {
    inventory_rules_dao.delete(rule_id)
  })
}
