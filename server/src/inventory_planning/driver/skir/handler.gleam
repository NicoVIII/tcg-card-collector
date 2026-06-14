import composition.{type Dependencies}
import gleam/list
import inventory_planning/application/handler as inventory_planning_handler
import inventory_planning/application/queries/list_rules/ports as list_rules_ports
import inventory_planning/application/queries/projection/ports as projection_ports
import skir/skirout/inventory_planning/commands as inventory_planning_commands
import skir/skirout/inventory_planning/queries as inventory_planning_queries
import skir_client/service

pub fn register(
  svc: service.Service(Nil, Dependencies, Nil),
) -> service.Service(Nil, Dependencies, Nil) {
  svc
  |> service.add_method(
    inventory_planning_commands.upsert_inventory_rule_method(),
    handle_upsert_inventory_rule,
  )
  |> service.add_method(
    inventory_planning_commands.delete_inventory_rule_method(),
    handle_delete_inventory_rule,
  )
  |> service.add_method(
    inventory_planning_queries.list_inventory_rules_method(),
    handle_list_inventory_rules,
  )
  |> service.add_method(
    inventory_planning_queries.get_inventory_projection_method(),
    handle_get_inventory_projection,
  )
  |> service.add_method(
    inventory_planning_queries.get_planning_preferences_method(),
    handle_get_planning_preferences,
  )
  |> service.add_method(
    inventory_planning_commands.update_planning_preferences_method(),
    handle_update_planning_preferences,
  )
}

fn handle_upsert_inventory_rule(
  req: inventory_planning_commands.UpsertInventoryRuleRequest,
  req_meta: Nil,
  deps: Dependencies,
) -> #(
  Result(
    inventory_planning_commands.UpsertInventoryRuleResponse,
    service.ServiceError,
  ),
  Nil,
  Nil,
) {
  case
    inventory_planning_handler.upsert_inventory_rule(
      deps.upsert_inventory_rule_port,
      req.id,
      req.location_name,
      req.expression,
    )
  {
    Ok(_) -> #(
      Ok(inventory_planning_commands.UpsertInventoryRuleResponseSuccess),
      req_meta,
      Nil,
    )
    Error(_) -> #(
      Error(service.ServiceError(
        service.E400xBadRequest,
        "invalid inventory rule expression",
      )),
      req_meta,
      Nil,
    )
  }
}

fn handle_delete_inventory_rule(
  req: inventory_planning_commands.DeleteInventoryRuleRequest,
  req_meta: Nil,
  deps: Dependencies,
) -> #(
  Result(
    inventory_planning_commands.DeleteInventoryRuleResponse,
    service.ServiceError,
  ),
  Nil,
  Nil,
) {
  inventory_planning_handler.delete_inventory_rule(
    deps.delete_inventory_rule_port,
    req.id,
  )

  #(
    Ok(inventory_planning_commands.DeleteInventoryRuleResponseSuccess),
    req_meta,
    Nil,
  )
}

fn handle_list_inventory_rules(
  _: inventory_planning_queries.ListInventoryRulesRequest,
  req_meta: Nil,
  deps: Dependencies,
) -> #(
  Result(inventory_planning_queries.InventoryRuleList, service.ServiceError),
  Nil,
  Nil,
) {
  let rules =
    inventory_planning_handler.list_inventory_rules(
      deps.list_inventory_rules_port,
    )
  let response =
    inventory_planning_queries.inventory_rule_list_new(
      list.map(rules, map_inventory_rule),
      list.length(rules),
    )

  #(Ok(response), req_meta, Nil)
}

fn handle_get_inventory_projection(
  req: inventory_planning_queries.InventoryProjectionRequest,
  req_meta: Nil,
  deps: Dependencies,
) -> #(
  Result(inventory_planning_queries.InventoryProjection, service.ServiceError),
  Nil,
  Nil,
) {
  let rows_result =
    inventory_planning_handler.inventory_projection(
      deps.inventory_projection_port,
      req.sort_by,
      req.group_by,
    )

  case rows_result {
    Ok(rows) -> {
      let response =
        inventory_planning_queries.inventory_projection_new(
          list.map(rows, map_inventory_projection_row),
          list.length(rows),
        )

      #(Ok(response), req_meta, Nil)
    }
    Error(inventory_planning_handler.InvalidSortBy) -> #(
      Error(service.ServiceError(service.E400xBadRequest, "invalid sort_by")),
      req_meta,
      Nil,
    )
    Error(inventory_planning_handler.InvalidGroupBy) -> #(
      Error(service.ServiceError(service.E400xBadRequest, "invalid group_by")),
      req_meta,
      Nil,
    )
  }
}

fn handle_get_planning_preferences(
  _: inventory_planning_queries.GetPlanningPreferencesRequest,
  req_meta: Nil,
  deps: Dependencies,
) -> #(
  Result(inventory_planning_queries.PlanningPreferences, service.ServiceError),
  Nil,
  Nil,
) {
  let current =
    inventory_planning_handler.get_planning_preferences(
      deps.get_planning_preferences_port,
    )
  let response =
    inventory_planning_queries.planning_preferences_new(
      current.default_grouping,
      current.default_sort,
    )

  #(Ok(response), req_meta, Nil)
}

fn handle_update_planning_preferences(
  req: inventory_planning_commands.UpdatePlanningPreferencesRequest,
  req_meta: Nil,
  deps: Dependencies,
) -> #(
  Result(
    inventory_planning_commands.UpdatePlanningPreferencesResponse,
    service.ServiceError,
  ),
  Nil,
  Nil,
) {
  inventory_planning_handler.update_planning_preferences(
    deps.update_planning_preferences_port,
    req.default_sort,
    req.default_grouping,
  )

  #(
    Ok(inventory_planning_commands.UpdatePlanningPreferencesResponseSuccess),
    req_meta,
    Nil,
  )
}

fn map_inventory_rule(
  rule: list_rules_ports.InventoryRuleReadModel,
) -> inventory_planning_queries.InventoryRule {
  inventory_planning_queries.inventory_rule_new(
    rule.expression,
    rule.id,
    rule.location_name,
  )
}

fn map_inventory_projection_row(
  row: projection_ports.InventoryProjectionReadModel,
) -> inventory_planning_queries.InventoryProjectionRow {
  inventory_planning_queries.inventory_projection_row_new(
    row.card_name,
    row.group_value,
    row.location_name,
    row.quantity,
    row.set_code,
  )
}
