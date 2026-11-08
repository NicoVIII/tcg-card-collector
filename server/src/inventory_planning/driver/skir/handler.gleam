import gleam/list
import inventory_planning/application/commands/add_to_managed_location/handler as add_to_managed_location_handler
import inventory_planning/application/commands/create_managed_location/handler as create_managed_location_handler
import inventory_planning/application/commands/delete_managed_location/handler as delete_managed_location_handler
import inventory_planning/application/commands/delete_rule/handler as delete_rule_handler
import inventory_planning/application/commands/mark_cards_placed/handler as mark_cards_placed_handler
import inventory_planning/application/commands/relocate_placed_cards/handler as relocate_placed_cards_handler
import inventory_planning/application/commands/remove_from_managed_location/handler as remove_from_managed_location_handler
import inventory_planning/application/commands/rename_managed_location/handler as rename_managed_location_handler
import inventory_planning/application/commands/reorder_rules/handler as reorder_rules_handler
import inventory_planning/application/commands/unmark_cards_placed/handler as unmark_cards_placed_handler
import inventory_planning/application/commands/update_bulk_spec/handler as update_bulk_spec_handler
import inventory_planning/application/commands/upsert_rule/handler as upsert_rule_handler
import inventory_planning/application/queries/get_bulk_spec/handler as get_bulk_spec_handler
import inventory_planning/application/queries/list_managed_locations/handler as list_managed_locations_handler
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

fn handle_reorder_inventory_rules(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  inventory_planning_commands.ReorderInventoryRulesRequest,
  inventory_planning_commands.ReorderInventoryRulesResponse,
  context,
) {
  fn(req: inventory_planning_commands.ReorderInventoryRulesRequest, _, ctx) {
    reorder_rules_handler.execute(
      reorder_rules_handler.ReorderInventoryRulesCommand(
        ordered_ids: req.ordered_ids,
      ),
      get_dependencies(ctx).reorder_inventory_rules_ports,
    )
    |> inventory_planning_skir_codec.map_reorder_inventory_rules_result
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

fn handle_relocate_placed_cards(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  inventory_planning_commands.RelocatePlacedCardsRequest,
  inventory_planning_commands.RelocatePlacedCardsResponse,
  context,
) {
  fn(req: inventory_planning_commands.RelocatePlacedCardsRequest, _, ctx) {
    relocate_placed_cards_handler.execute(
      relocate_placed_cards_handler.RelocatePlacedCardsCommand(
        from_location: req.from_location_name,
        to_location: req.to_location_name,
      ),
      get_dependencies(ctx).relocate_placed_cards_port,
    )
    |> inventory_planning_skir_codec.map_relocate_placed_cards_result
    |> helpers.respond
  }
}

fn handle_list_managed_locations(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  inventory_planning_queries.ListManagedLocationsRequest,
  inventory_planning_queries.ManagedLocationList,
  context,
) {
  fn(_: inventory_planning_queries.ListManagedLocationsRequest, _, ctx) {
    list_managed_locations_handler.execute(
      list_managed_locations_handler.ListManagedLocationsQuery,
      get_dependencies(ctx).list_managed_locations_port,
    )
    |> helpers.map_query(
      inventory_planning_skir_codec.map_managed_location_list,
    )
    |> helpers.respond
  }
}

fn handle_create_managed_location(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  inventory_planning_commands.CreateManagedLocationRequest,
  inventory_planning_commands.ManagedLocationCreated,
  context,
) {
  fn(req: inventory_planning_commands.CreateManagedLocationRequest, _, ctx) {
    create_managed_location_handler.execute(
      create_managed_location_handler.CreateManagedLocationCommand(
        id: req.id,
        name: req.name,
        kind: inventory_planning_skir_codec.command_managed_location_kind_to_string(
          req.kind,
        ),
      ),
      get_dependencies(ctx).create_managed_location_ports,
    )
    |> inventory_planning_skir_codec.map_create_managed_location_result
    |> helpers.respond
  }
}

fn handle_rename_managed_location(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  inventory_planning_commands.RenameManagedLocationRequest,
  inventory_planning_commands.ManagedLocationRenamed,
  context,
) {
  fn(req: inventory_planning_commands.RenameManagedLocationRequest, _, ctx) {
    rename_managed_location_handler.execute(
      rename_managed_location_handler.RenameManagedLocationCommand(
        id: req.id,
        name: req.name,
      ),
      get_dependencies(ctx).rename_managed_location_ports,
    )
    |> inventory_planning_skir_codec.map_rename_managed_location_result
    |> helpers.respond
  }
}

fn handle_delete_managed_location(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  inventory_planning_commands.DeleteManagedLocationRequest,
  inventory_planning_commands.ManagedLocationDeleted,
  context,
) {
  fn(req: inventory_planning_commands.DeleteManagedLocationRequest, _, ctx) {
    delete_managed_location_handler.execute(
      delete_managed_location_handler.DeleteManagedLocationCommand(id: req.id),
      get_dependencies(ctx).delete_managed_location_ports,
    )
    |> inventory_planning_skir_codec.map_delete_managed_location_result
    |> helpers.respond
  }
}

fn handle_add_to_managed_location(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  inventory_planning_commands.AddToManagedLocationRequest,
  inventory_planning_commands.ManagedLocationMembersAdded,
  context,
) {
  fn(req: inventory_planning_commands.AddToManagedLocationRequest, _, ctx) {
    add_to_managed_location_handler.execute(
      add_to_managed_location_handler.AddToManagedLocationCommand(
        id: req.id,
        copies: list.map(
          req.copies,
          inventory_planning_skir_codec.to_add_raw_copy,
        ),
      ),
      get_dependencies(ctx).add_to_managed_location_ports,
    )
    |> inventory_planning_skir_codec.map_add_to_managed_location_result
    |> helpers.respond
  }
}

fn handle_remove_from_managed_location(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  inventory_planning_commands.RemoveFromManagedLocationRequest,
  inventory_planning_commands.ManagedLocationMembersRemoved,
  context,
) {
  fn(req: inventory_planning_commands.RemoveFromManagedLocationRequest, _, ctx) {
    remove_from_managed_location_handler.execute(
      remove_from_managed_location_handler.RemoveFromManagedLocationCommand(
        id: req.id,
        copies: list.map(
          req.copies,
          inventory_planning_skir_codec.to_remove_raw_copy,
        ),
      ),
      get_dependencies(ctx).remove_from_managed_location_ports,
    )
    |> inventory_planning_skir_codec.map_remove_from_managed_location_result
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
    inventory_planning_commands.reorder_inventory_rules_method(),
    handle_reorder_inventory_rules(get_dependencies),
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
  |> service.add_method(
    inventory_planning_commands.relocate_placed_cards_method(),
    handle_relocate_placed_cards(get_dependencies),
  )
  |> service.add_method(
    inventory_planning_queries.list_managed_locations_method(),
    handle_list_managed_locations(get_dependencies),
  )
  |> service.add_method(
    inventory_planning_commands.create_managed_location_method(),
    handle_create_managed_location(get_dependencies),
  )
  |> service.add_method(
    inventory_planning_commands.rename_managed_location_method(),
    handle_rename_managed_location(get_dependencies),
  )
  |> service.add_method(
    inventory_planning_commands.delete_managed_location_method(),
    handle_delete_managed_location(get_dependencies),
  )
  |> service.add_method(
    inventory_planning_commands.add_to_managed_location_method(),
    handle_add_to_managed_location(get_dependencies),
  )
  |> service.add_method(
    inventory_planning_commands.remove_from_managed_location_method(),
    handle_remove_from_managed_location(get_dependencies),
  )
}
