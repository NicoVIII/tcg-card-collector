import application/inventory_planning/ports
import application/inventory_planning/service
import domain/inventory_planning/grouping_strategy
import domain/inventory_planning/sort_strategy

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
  let InventoryProjectionRequest(sort_by: raw_sort, group_by: raw_group) =
    request

  let sort_by =
    raw_sort
    |> sort_strategy.parse
    |> fn(r) {
      case r {
        Ok(s) -> sort_strategy.to_string(s)
        Error(_) -> sort_strategy.to_string(sort_strategy.ByCardName)
      }
    }

  let group_by =
    raw_group
    |> grouping_strategy.parse
    |> fn(r) {
      case r {
        Ok(g) -> grouping_strategy.to_string(g)
        Error(_) -> grouping_strategy.to_string(grouping_strategy.ByLocation)
      }
    }

  service.inventory_projection(repository, sort_by:, group_by:)
}
