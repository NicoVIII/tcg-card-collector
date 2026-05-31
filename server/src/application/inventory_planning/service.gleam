import application/inventory_planning/ports

pub fn upsert_inventory_rule(
  repository: ports.InventoryPlanningRepository,
  rule: ports.InventoryRuleWriteModel,
) -> Nil {
  ports.upsert(repository, rule)
}

pub fn list_inventory_rules(
  repository: ports.InventoryPlanningRepository,
) -> List(ports.InventoryRuleReadModel) {
  ports.list(repository)
}

pub fn delete_inventory_rule(
  repository: ports.InventoryPlanningRepository,
  rule_id: String,
) -> Nil {
  ports.delete(repository, rule_id)
}

pub fn inventory_projection(
  repository: ports.InventoryPlanningRepository,
  sort_by sort_by: String,
  group_by group_by: String,
) -> List(ports.InventoryProjectionReadModel) {
  ports.projection(repository, sort_by:, group_by:)
}
