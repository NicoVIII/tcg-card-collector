import gleam/list
import inventory_planning/application/commands/delete_rule/handler as delete_rule_handler
import inventory_planning/application/commands/mark_cards_placed/handler as mark_cards_placed_handler
import inventory_planning/application/commands/unmark_cards_placed/handler as unmark_cards_placed_handler
import inventory_planning/application/commands/update_bulk_spec/handler as update_bulk_spec_handler
import inventory_planning/application/commands/update_preferences/handler as update_preferences_handler
import inventory_planning/application/commands/upsert_rule/handler as upsert_rule_handler
import inventory_planning/application/queries/get_bulk_spec/handler as get_bulk_spec_handler
import inventory_planning/application/queries/get_preferences/handler as get_preferences_handler
import inventory_planning/application/queries/list_rules/handler as list_rules_handler
import inventory_planning/application/queries/list_rules/ports as list_rules_ports
import inventory_planning/application/queries/placement_guidance/handler as placement_guidance_handler
import inventory_planning/application/queries/projection/handler as projection_handler
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
  |> service.add_method(
    inventory_planning_queries.get_bulk_spec_method(),
    handle_get_bulk_spec(get_dependencies),
  )
  |> service.add_method(
    inventory_planning_commands.update_bulk_spec_method(),
    handle_update_bulk_spec(get_dependencies),
  )
  |> service.add_method(
    inventory_planning_queries.get_placement_guidance_method(),
    handle_get_placement_guidance(get_dependencies),
  )
  |> service.add_method(
    inventory_planning_commands.mark_cards_placed_method(),
    handle_mark_cards_placed(get_dependencies),
  )
  |> service.add_method(
    inventory_planning_commands.unmark_cards_placed_method(),
    handle_unmark_cards_placed(get_dependencies),
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
          position: req.position,
          selector: req.selector,
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
    _: inventory_planning_queries.InventoryProjectionRequest,
    req_meta: Nil,
    ctx: context,
  ) -> #(
    Result(inventory_planning_queries.InventoryProjection, service.ServiceError),
    Nil,
    Nil,
  ) {
    case
      projection_handler.execute(
        projection_handler.InventoryProjectionQuery,
        get_dependencies(ctx).inventory_projection_ports,
      )
    {
      Ok(projection) -> #(
        Ok(inventory_planning_skir_codec.map_projection(projection)),
        req_meta,
        Nil,
      )
      Error(reason) -> #(
        Error(service.ServiceError(service.E500xInternalServerError, reason)),
        req_meta,
        Nil,
      )
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

fn handle_get_bulk_spec(get_dependencies: fn(context) -> Dependencies) {
  fn(
    _: inventory_planning_queries.GetBulkSpecRequest,
    req_meta: Nil,
    ctx: context,
  ) -> #(
    Result(inventory_planning_queries.BulkSpec, service.ServiceError),
    Nil,
    Nil,
  ) {
    let current =
      get_bulk_spec_handler.execute(
        get_bulk_spec_handler.GetBulkSpecQuery,
        get_dependencies(ctx).get_bulk_spec_port,
      )
    let response =
      inventory_planning_queries.bulk_spec_new(
        current.location_name,
        current.sort_keys,
      )
    #(Ok(response), req_meta, Nil)
  }
}

fn handle_update_bulk_spec(get_dependencies: fn(context) -> Dependencies) {
  fn(
    req: inventory_planning_commands.UpdateBulkSpecRequest,
    req_meta: Nil,
    ctx: context,
  ) -> #(
    Result(
      inventory_planning_commands.UpdateBulkSpecResponse,
      service.ServiceError,
    ),
    Nil,
    Nil,
  ) {
    let result =
      update_bulk_spec_handler.execute(
        update_bulk_spec_handler.UpdateBulkSpecCommand(
          location_name: req.location_name,
          sort_keys: req.sort_keys,
        ),
        get_dependencies(ctx).update_bulk_spec_port,
      )
    #(
      inventory_planning_skir_codec.map_update_bulk_spec_result(result),
      req_meta,
      Nil,
    )
  }
}

fn handle_get_placement_guidance(
  get_dependencies: fn(context) -> Dependencies,
) {
  fn(
    _: inventory_planning_queries.PlacementGuidanceRequest,
    req_meta: Nil,
    ctx: context,
  ) -> #(
    Result(inventory_planning_queries.PlacementGuidance, service.ServiceError),
    Nil,
    Nil,
  ) {
    case
      placement_guidance_handler.execute(
        placement_guidance_handler.GetPlacementGuidanceQuery,
        get_dependencies(ctx).get_placement_guidance_ports,
      )
    {
      Ok(guidance) -> #(
        Ok(inventory_planning_skir_codec.map_placement_guidance(guidance)),
        req_meta,
        Nil,
      )
      Error(reason) -> #(
        Error(service.ServiceError(service.E500xInternalServerError, reason)),
        req_meta,
        Nil,
      )
    }
  }
}

fn handle_mark_cards_placed(get_dependencies: fn(context) -> Dependencies) {
  fn(
    req: inventory_planning_commands.MarkCardsPlacedRequest,
    req_meta: Nil,
    ctx: context,
  ) -> #(
    Result(
      inventory_planning_commands.MarkCardsPlacedResponse,
      service.ServiceError,
    ),
    Nil,
    Nil,
  ) {
    let result =
      mark_cards_placed_handler.execute(
        mark_cards_placed_handler.MarkCardsPlacedCommand(placements: list.map(
          req.placements,
          map_mark_raw_placement,
        )),
        get_dependencies(ctx).mark_cards_placed_port,
      )
    #(
      inventory_planning_skir_codec.map_mark_cards_placed_result(result),
      req_meta,
      Nil,
    )
  }
}

fn handle_unmark_cards_placed(get_dependencies: fn(context) -> Dependencies) {
  fn(
    req: inventory_planning_commands.UnmarkCardsPlacedRequest,
    req_meta: Nil,
    ctx: context,
  ) -> #(
    Result(
      inventory_planning_commands.UnmarkCardsPlacedResponse,
      service.ServiceError,
    ),
    Nil,
    Nil,
  ) {
    let result =
      unmark_cards_placed_handler.execute(
        unmark_cards_placed_handler.UnmarkCardsPlacedCommand(
          placements: list.map(req.placements, map_unmark_raw_placement),
        ),
        get_dependencies(ctx).unmark_cards_placed_port,
      )
    #(
      inventory_planning_skir_codec.map_unmark_cards_placed_result(result),
      req_meta,
      Nil,
    )
  }
}

fn map_mark_raw_placement(
  placement: inventory_planning_commands.CardPlacement,
) -> mark_cards_placed_handler.RawPlacement {
  mark_cards_placed_handler.RawPlacement(
    set_code: placement.set_code,
    collector_number: placement.collector_number,
    location_name: placement.location_name,
    quantity: placement.quantity,
  )
}

fn map_unmark_raw_placement(
  placement: inventory_planning_commands.CardPlacement,
) -> unmark_cards_placed_handler.RawPlacement {
  unmark_cards_placed_handler.RawPlacement(
    set_code: placement.set_code,
    collector_number: placement.collector_number,
    location_name: placement.location_name,
    quantity: placement.quantity,
  )
}

fn map_inventory_rule(
  rule: list_rules_ports.InventoryRuleReadModel,
) -> inventory_planning_queries.InventoryRule {
  inventory_planning_queries.inventory_rule_new(
    rule.expression,
    rule.id,
    rule.location_name,
    rule.position,
    rule.selector,
  )
}
