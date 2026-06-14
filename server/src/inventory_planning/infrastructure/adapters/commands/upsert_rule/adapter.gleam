import inventory_planning/application/commands/upsert_rule/ports
import inventory_planning/infrastructure/stores/inventory_rules_store

pub fn new() -> ports.UpsertInventoryRulePort {
  ports.UpsertInventoryRulePort(upsert_rule: fn(rule) {
    let ports.InventoryRuleWriteModel(
      id: id,
      location_name: location_name,
      expression: expression,
    ) = rule
    inventory_rules_store.upsert(id, location_name, expression)
  })
}
