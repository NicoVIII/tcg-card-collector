import inventory_planning/application/commands/upsert_rule/ports
import inventory_planning/infrastructure/daos/inventory_rules_dao

pub fn new() -> ports.UpsertInventoryRulePort {
  ports.UpsertInventoryRulePort(upsert_rule: fn(rule) {
    let ports.InventoryRuleWriteModel(
      id: id,
      location_name: location_name,
      expression: expression,
      position: position,
      selector: selector,
      sort_keys: sort_keys,
    ) = rule
    inventory_rules_dao.upsert(
      id,
      location_name,
      expression,
      position,
      selector,
      sort_keys,
    )
  })
}
