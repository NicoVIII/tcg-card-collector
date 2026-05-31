import application/inventory_planning/ports
import application/inventory_planning/service

pub type UpsertInventoryRuleRequest {
  UpsertInventoryRuleRequest(
    id: String,
    location_name: String,
    expression: String,
  )
}

pub type DeleteInventoryRuleRequest {
  DeleteInventoryRuleRequest(id: String)
}

pub type InventoryProjectionRequest {
  InventoryProjectionRequest(sort_by: String, group_by: String)
}

pub fn upsert_inventory_rule(
  repository: ports.InventoryPlanningRepository,
  request: UpsertInventoryRuleRequest,
) -> Nil {
  let UpsertInventoryRuleRequest(
    id: id,
    location_name: location_name,
    expression: expression,
  ) = request

  service.upsert_inventory_rule(
    repository,
    ports.InventoryRuleWriteModel(
      id: id,
      location_name: location_name,
      expression: expression,
    ),
  )
}

pub fn delete_inventory_rule(
  repository: ports.InventoryPlanningRepository,
  request: DeleteInventoryRuleRequest,
) -> Nil {
  let DeleteInventoryRuleRequest(id: id) = request
  service.delete_inventory_rule(repository, id)
}

pub fn list_inventory_rules(
  repository: ports.InventoryPlanningRepository,
) -> List(ports.InventoryRuleReadModel) {
  service.list_inventory_rules(repository)
}

pub fn inventory_projection(
  repository: ports.InventoryPlanningRepository,
  request: InventoryProjectionRequest,
) -> List(ports.InventoryProjectionReadModel) {
  let InventoryProjectionRequest(sort_by: sort_by, group_by: group_by) = request
  service.inventory_projection(repository, sort_by:, group_by:)
}
