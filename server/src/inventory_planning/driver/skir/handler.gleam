import gleam/list
import inventory_planning/application/commands/delete_rule/handler as delete_rule_handler
import inventory_planning/application/commands/mark_cards_placed/handler as mark_cards_placed_handler
import inventory_planning/application/commands/unmark_cards_placed/handler as unmark_cards_placed_handler
import inventory_planning/application/commands/update_bulk_spec/handler as update_bulk_spec_handler
import inventory_planning/application/commands/upsert_rule/handler as upsert_rule_handler
import inventory_planning/application/queries/get_bulk_spec/handler as get_bulk_spec_handler
import inventory_planning/application/queries/list_rules/handler as list_rules_handler
import inventory_planning/application/queries/placed_ledger/handler as placed_ledger_handler
import inventory_planning/application/queries/projection/handler as projection_handler
import inventory_planning/driver/dependencies.{type Dependencies}
import inventory_planning/driver/skir/codec as inventory_planning_skir_codec
import shared/driver/skir/helpers
import shared/driver/skir/skirout/inventory_planning/commands as inventory_planning_commands
import shared/driver/skir/skirout/inventory_planning/queries as inventory_planning_queries
import skir_client/service

fn handle_upsert_inventory_rule(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  inventory_planning_commands.UpsertInventoryRuleRequest,
  inventory_planning_commands.UpsertInventoryRuleResponse,
  context,
) {
  fn(req: inventory_planning_commands.UpsertInventoryRuleRequest, _, ctx) {
    upsert_rule_handler.execute(
      upsert_rule_handler.UpsertInventoryRuleCommand(
        id: req.id,
        location_name: req.location_name,
        expression: req.expression,
        position: req.position,
        selector: req.selector,
        sort_keys: req.sort_keys,
      ),
      get_dependencies(ctx).upsert_inventory_rule_port,
    )
    |> inventory_planning_skir_codec.map_upsert_inventory_rule_result
    |> helpers.respond
  }
}

fn handle_delete_inventory_rule(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  inventory_planning_commands.DeleteInventoryRuleRequest,
  inventory_planning_commands.DeleteInventoryRuleResponse,
  context,
) {
  fn(req: inventory_planning_commands.DeleteInventoryRuleRequest, _, ctx) {
    delete_rule_handler.execute(
      delete_rule_handler.DeleteInventoryRuleCommand(id: req.id),
      get_dependencies(ctx).delete_inventory_rule_port,
    )
    |> inventory_planning_skir_codec.map_delete_inventory_rule_result
    |> helpers.respond
  }
}

fn handle_list_inventory_rules(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  inventory_planning_queries.ListInventoryRulesRequest,
  inventory_planning_queries.InventoryRuleList,
  context,
) {
  fn(_: inventory_planning_queries.ListInventoryRulesRequest, _, ctx) {
    list_rules_handler.execute(
      list_rules_handler.ListInventoryRulesQuery,
      get_dependencies(ctx).list_inventory_rules_port,
    )
    |> helpers.map_query(inventory_planning_skir_codec.map_inventory_rule_list)
    |> helpers.respond
  }
}

fn handle_get_inventory_projection(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  inventory_planning_queries.InventoryProjectionRequest,
  inventory_planning_queries.InventoryProjection,
  context,
) {
  fn(_: inventory_planning_queries.InventoryProjectionRequest, _, ctx) {
    projection_handler.execute(
      projection_handler.InventoryProjectionQuery,
      get_dependencies(ctx).inventory_projection_ports,
    )
    |> helpers.map_query(inventory_planning_skir_codec.map_projection)
    |> helpers.respond
  }
}

fn handle_get_bulk_spec(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  inventory_planning_queries.GetBulkSpecRequest,
  inventory_planning_queries.BulkSpec,
  context,
) {
  fn(_: inventory_planning_queries.GetBulkSpecRequest, _, ctx) {
    get_bulk_spec_handler.execute(
      get_bulk_spec_handler.GetBulkSpecQuery,
      get_dependencies(ctx).get_bulk_spec_port,
    )
    |> helpers.map_query(inventory_planning_skir_codec.map_bulk_spec)
    |> helpers.respond
  }
}

fn handle_update_bulk_spec(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  inventory_planning_commands.UpdateBulkSpecRequest,
  inventory_planning_commands.UpdateBulkSpecResponse,
  context,
) {
  fn(req: inventory_planning_commands.UpdateBulkSpecRequest, _, ctx) {
    update_bulk_spec_handler.execute(
      update_bulk_spec_handler.UpdateBulkSpecCommand(
        location_name: req.location_name,
        sort_keys: req.sort_keys,
      ),
      get_dependencies(ctx).update_bulk_spec_port,
    )
    |> inventory_planning_skir_codec.map_update_bulk_spec_result
    |> helpers.respond
  }
}

fn handle_get_placed_ledger(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  inventory_planning_queries.PlacedLedgerRequest,
  inventory_planning_queries.PlacedLedger,
  context,
) {
  fn(_: inventory_planning_queries.PlacedLedgerRequest, _, ctx) {
    placed_ledger_handler.execute(
      placed_ledger_handler.GetPlacedLedgerQuery,
      get_dependencies(ctx).get_placed_ledger_port,
    )
    |> helpers.map_query(inventory_planning_skir_codec.map_placed_ledger)
    |> helpers.respond
  }
}

fn handle_mark_cards_placed(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  inventory_planning_commands.MarkCardsPlacedRequest,
  inventory_planning_commands.MarkCardsPlacedResponse,
  context,
) {
  fn(req: inventory_planning_commands.MarkCardsPlacedRequest, _, ctx) {
    mark_cards_placed_handler.execute(
      mark_cards_placed_handler.MarkCardsPlacedCommand(placements: list.map(
        req.placements,
        inventory_planning_skir_codec.to_mark_raw_placement,
      )),
      get_dependencies(ctx).mark_cards_placed_port,
    )
    |> inventory_planning_skir_codec.map_mark_cards_placed_result
    |> helpers.respond
  }
}

fn handle_unmark_cards_placed(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  inventory_planning_commands.UnmarkCardsPlacedRequest,
  inventory_planning_commands.UnmarkCardsPlacedResponse,
  context,
) {
  fn(req: inventory_planning_commands.UnmarkCardsPlacedRequest, _, ctx) {
    unmark_cards_placed_handler.execute(
      unmark_cards_placed_handler.UnmarkCardsPlacedCommand(placements: list.map(
        req.placements,
        inventory_planning_skir_codec.to_unmark_raw_placement,
      )),
      get_dependencies(ctx).unmark_cards_placed_port,
    )
    |> inventory_planning_skir_codec.map_unmark_cards_placed_result
    |> helpers.respond
  }
}

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
    inventory_planning_queries.get_bulk_spec_method(),
    handle_get_bulk_spec(get_dependencies),
  )
  |> service.add_method(
    inventory_planning_commands.update_bulk_spec_method(),
    handle_update_bulk_spec(get_dependencies),
  )
  |> service.add_method(
    inventory_planning_queries.get_placed_ledger_method(),
    handle_get_placed_ledger(get_dependencies),
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
