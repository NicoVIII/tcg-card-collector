import gleam/list
import inventory_planning/application/commands/delete_rule/handler as delete_rule_handler
import inventory_planning/application/commands/update_preferences/handler as update_preferences_handler
import inventory_planning/application/commands/upsert_rule/handler as upsert_rule_handler
import inventory_planning/application/queries/get_preferences/handler as get_preferences_handler
import inventory_planning/application/queries/list_rules/handler as list_rules_handler
import inventory_planning/application/queries/list_rules/ports as list_rules_ports
import inventory_planning/application/queries/projection/handler as projection_handler
import inventory_planning/application/queries/projection/ports as projection_ports
import inventory_planning/domain/grouping_strategy
import inventory_planning/domain/sort_strategy
import inventory_planning/driver/dependencies.{type Dependencies}
import inventory_planning/driver/skir/codec as inventory_planning_skir_codec
import shared/driver/skir/skirout/inventory_planning/commands as inventory_planning_commands
import shared/driver/skir/skirout/inventory_planning/queries as inventory_planning_queries
import skir_client/service

pub fn register(
  svc: service.Service(Nil, context, Nil),
  get_dependencies: fn(context) -> Dependencies,
) -> service.Service(Nil, context, Nil) {
  svc
  |> service.add_method(
    inventory_planning_commands.upsert_inventory_rule_method(),
    handle_upsert_inventory_rule(get_dependencies),
  )
  |> service.add_method(
    inventory_planning_commands.delete_inventory_rule_method(),
    handle_delete_inventory_rule(get_dependencies),
  )
  |> service.add_method(
    inventory_planning_queries.list_inventory_rules_method(),
    handle_list_inventory_rules(get_dependencies),
  )
  |> service.add_method(
    inventory_planning_queries.get_inventory_projection_method(),
    handle_get_inventory_projection(get_dependencies),
  )
  |> service.add_method(
    inventory_planning_queries.get_planning_preferences_method(),
    handle_get_planning_preferences(get_dependencies),
  )
  |> service.add_method(
    inventory_planning_commands.update_planning_preferences_method(),
    handle_update_planning_preferences(get_dependencies),
  )
}

fn handle_upsert_inventory_rule(get_dependencies: fn(context) -> Dependencies) {
  fn(
    req: inventory_planning_commands.UpsertInventoryRuleRequest,
    req_meta: Nil,
    ctx: context,
  ) -> #(
    Result(
      inventory_planning_commands.UpsertInventoryRuleResponse,
      service.ServiceError,
    ),
    Nil,
    Nil,
  ) {
    let result =
      upsert_rule_handler.execute(
        upsert_rule_handler.UpsertInventoryRuleCommand(
          id: req.id,
          location_name: req.location_name,
          expression: req.expression,
        ),
        get_dependencies(ctx).upsert_inventory_rule_port,
      )
    #(
      inventory_planning_skir_codec.map_upsert_inventory_rule_result(result),
      req_meta,
      Nil,
    )
  }
}

fn handle_delete_inventory_rule(get_dependencies: fn(context) -> Dependencies) {
  fn(
    req: inventory_planning_commands.DeleteInventoryRuleRequest,
    req_meta: Nil,
    ctx: context,
  ) -> #(
    Result(
      inventory_planning_commands.DeleteInventoryRuleResponse,
      service.ServiceError,
    ),
    Nil,
    Nil,
  ) {
    let result =
      delete_rule_handler.execute(
        delete_rule_handler.DeleteInventoryRuleCommand(id: req.id),
        get_dependencies(ctx).delete_inventory_rule_port,
      )
    #(
      inventory_planning_skir_codec.map_delete_inventory_rule_result(result),
      req_meta,
      Nil,
    )
  }
}

fn handle_list_inventory_rules(get_dependencies: fn(context) -> Dependencies) {
  fn(
    _: inventory_planning_queries.ListInventoryRulesRequest,
    req_meta: Nil,
    ctx: context,
  ) -> #(
    Result(inventory_planning_queries.InventoryRuleList, service.ServiceError),
    Nil,
    Nil,
  ) {
    let rules =
      list_rules_handler.execute(
        list_rules_handler.ListInventoryRulesQuery,
        get_dependencies(ctx).list_inventory_rules_port,
      )
    let response =
      inventory_planning_queries.inventory_rule_list_new(
        list.map(rules, map_inventory_rule),
        list.length(rules),
      )
    #(Ok(response), req_meta, Nil)
  }
}

fn handle_get_inventory_projection(
  get_dependencies: fn(context) -> Dependencies,
) {
  fn(
    req: inventory_planning_queries.InventoryProjectionRequest,
    req_meta: Nil,
    ctx: context,
  ) -> #(
    Result(inventory_planning_queries.InventoryProjection, service.ServiceError),
    Nil,
    Nil,
  ) {
    case sort_strategy.parse(req.sort_by) {
      Error(_) -> #(
        Error(service.ServiceError(service.E400xBadRequest, "invalid sort_by")),
        req_meta,
        Nil,
      )
      Ok(sort_by) ->
        case grouping_strategy.parse(req.group_by) {
          Error(_) -> #(
            Error(service.ServiceError(
              service.E400xBadRequest,
              "invalid group_by",
            )),
            req_meta,
            Nil,
          )
          Ok(group_by) ->
            case
              projection_handler.execute(
                projection_handler.InventoryProjectionQuery(sort_by:, group_by:),
                get_dependencies(ctx).inventory_projection_ports,
              )
            {
              Ok(rows) -> {
                let response =
                  inventory_planning_queries.inventory_projection_new(
                    list.map(rows, map_inventory_projection_row),
                    list.length(rows),
                  )
                #(Ok(response), req_meta, Nil)
              }
              Error(reason) -> #(
                Error(service.ServiceError(
                  service.E500xInternalServerError,
                  reason,
                )),
                req_meta,
                Nil,
              )
            }
        }
    }
  }
}

fn handle_get_planning_preferences(
  get_dependencies: fn(context) -> Dependencies,
) {
  fn(
    _: inventory_planning_queries.GetPlanningPreferencesRequest,
    req_meta: Nil,
    ctx: context,
  ) -> #(
    Result(inventory_planning_queries.PlanningPreferences, service.ServiceError),
    Nil,
    Nil,
  ) {
    let current =
      get_preferences_handler.execute(
        get_preferences_handler.GetPlanningPreferencesQuery,
        get_dependencies(ctx).get_planning_preferences_port,
      )
    let response =
      inventory_planning_queries.planning_preferences_new(
        current.default_grouping,
        current.default_sort,
      )
    #(Ok(response), req_meta, Nil)
  }
}

fn handle_update_planning_preferences(
  get_dependencies: fn(context) -> Dependencies,
) {
  fn(
    req: inventory_planning_commands.UpdatePlanningPreferencesRequest,
    req_meta: Nil,
    ctx: context,
  ) -> #(
    Result(
      inventory_planning_commands.UpdatePlanningPreferencesResponse,
      service.ServiceError,
    ),
    Nil,
    Nil,
  ) {
    let result =
      update_preferences_handler.execute(
        update_preferences_handler.UpdatePlanningPreferencesCommand(
          default_sort: req.default_sort,
          default_grouping: req.default_grouping,
        ),
        get_dependencies(ctx).update_planning_preferences_port,
      )
    #(
      inventory_planning_skir_codec.map_update_preferences_result(result),
      req_meta,
      Nil,
    )
  }
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
