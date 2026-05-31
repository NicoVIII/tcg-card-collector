import application/inventory_planning/ports
import application/inventory_planning/service
import domain/inventory_planning/grouping_strategy
import domain/inventory_planning/sort_strategy
import gleam/string

pub type InventoryPlanningValidationError {
  InvalidSortBy
  InvalidGroupBy
  InvalidRuleExpression
}

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
) -> Result(Nil, InventoryPlanningValidationError) {
  let UpsertInventoryRuleRequest(
    id: id,
    location_name: location_name,
    expression: expression,
  ) = request

  case is_valid_rule_expression(expression) {
    False -> Error(InvalidRuleExpression)
    True -> {
      service.upsert_inventory_rule(
        repository,
        ports.InventoryRuleWriteModel(
          id: id,
          location_name: location_name,
          expression: expression,
        ),
      )

      Ok(Nil)
    }
  }
}

fn is_valid_rule_expression(expression: String) -> Bool {
  case string.split(expression, "=") {
    ["set_code", value] -> string.length(value) > 0
    _ -> False
  }
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
) -> Result(
  List(ports.InventoryProjectionReadModel),
  InventoryPlanningValidationError,
) {
  let InventoryProjectionRequest(sort_by: raw_sort, group_by: raw_group) =
    request

  case sort_strategy.parse(raw_sort) {
    Error(_) -> Error(InvalidSortBy)
    Ok(sort_by) ->
      case grouping_strategy.parse(raw_group) {
        Error(_) -> Error(InvalidGroupBy)
        Ok(group_by) ->
          Ok(service.inventory_projection(
            repository,
            sort_by: sort_strategy.to_string(sort_by),
            group_by: grouping_strategy.to_string(group_by),
          ))
      }
  }
}
