import inventory_planning/application/commands/delete_rule/ports
import inventory_planning/infrastructure/stores/inventory_rules_store

pub fn new() -> ports.DeleteInventoryRulePort {
  ports.DeleteInventoryRulePort(delete_rule: fn(rule_id) {
    inventory_rules_store.delete(rule_id)
  })
}
