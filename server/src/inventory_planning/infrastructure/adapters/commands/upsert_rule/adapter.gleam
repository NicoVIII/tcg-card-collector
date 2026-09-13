import inventory_planning/application/commands/upsert_rule/ports
import inventory_planning/infrastructure/daos/inventory_rules_dao

pub fn new() -> ports.UpsertInventoryRulePort {
  ports.UpsertInventoryRulePort(upsert_rule: fn(rule) {
    inventory_rules_dao.upsert(inventory_rules_dao.RuleRow(
      id: rule.id,
      location_name: rule.location_name,
      expression: rule.expression,
      position: rule.position,
      selector: rule.selector,
      sort_keys: rule.sort_keys,
    ))
  })
}
