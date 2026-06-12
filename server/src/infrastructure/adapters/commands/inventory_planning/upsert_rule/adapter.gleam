import application/commands/inventory_planning/upsert_rule/ports
import infrastructure/stores/inventory_planning/inventory_rules_store

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
