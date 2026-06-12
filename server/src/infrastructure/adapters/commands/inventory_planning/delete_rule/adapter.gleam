import application/commands/inventory_planning/delete_rule/ports
import infrastructure/stores/inventory_planning/inventory_rules_store

pub fn new() -> ports.DeleteInventoryRulePort {
  ports.DeleteInventoryRulePort(delete_rule: fn(rule_id) {
    inventory_rules_store.delete(rule_id)
  })
}
