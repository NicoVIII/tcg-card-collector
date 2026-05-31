import application/inventory_planning/ports
import driver/skir/inventory_planning_handler

pub fn upsert_inventory_rule(
  repository: ports.InventoryPlanningRepository,
  request: inventory_planning_handler.UpsertInventoryRuleRequest,
) -> Result(Nil, inventory_planning_handler.InventoryPlanningValidationError) {
  inventory_planning_handler.upsert_inventory_rule(repository, request)
}

pub fn delete_inventory_rule(
  repository: ports.InventoryPlanningRepository,
  request: inventory_planning_handler.DeleteInventoryRuleRequest,
) -> Nil {
  inventory_planning_handler.delete_inventory_rule(repository, request)
}

pub fn list_inventory_rules(
  repository: ports.InventoryPlanningRepository,
) -> List(ports.InventoryRuleReadModel) {
  inventory_planning_handler.list_inventory_rules(repository)
}

pub fn inventory_projection(
  repository: ports.InventoryPlanningRepository,
  request: inventory_planning_handler.InventoryProjectionRequest,
) -> Result(
  List(ports.InventoryProjectionReadModel),
  inventory_planning_handler.InventoryPlanningValidationError,
) {
  inventory_planning_handler.inventory_projection(repository, request)
}
