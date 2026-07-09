import gleam/list
import inventory_planning/application/commands/delete_rule/ports as delete_rule_ports
import inventory_planning/application/commands/mark_cards_placed/ports as mark_cards_placed_ports
import inventory_planning/application/commands/unmark_cards_placed/ports as unmark_cards_placed_ports
import inventory_planning/application/commands/update_bulk_spec/ports as update_bulk_spec_ports
import inventory_planning/application/commands/update_preferences/ports as update_preferences_ports
import inventory_planning/application/commands/upsert_rule/ports as upsert_rule_ports
import inventory_planning/application/queries/placed_ledger/ports as placed_ledger_ports
import inventory_planning/application/queries/projection/ports as projection_ports
import shared/driver/skir/skirout/inventory_planning/commands as inventory_planning_commands
import shared/driver/skir/skirout/inventory_planning/queries as inventory_planning_queries
import skir_client/service

pub fn map_projection(
  projection: projection_ports.Projection,
) -> inventory_planning_queries.InventoryProjection {
  inventory_planning_queries.inventory_projection_new(
    list.map(projection.locations, map_projection_location),
    projection.total_quantity,
    projection.unknown_count,
  )
}

fn map_projection_location(
  location: projection_ports.ProjectionLocation,
) -> inventory_planning_queries.ProjectionLocation {
  inventory_planning_queries.projection_location_new(
    list.map(location.cards, map_projection_card),
    location.location_name,
    location.rule_id,
    location.total_quantity,
  )
}

fn map_projection_card(
  card: projection_ports.ProjectionCard,
) -> inventory_planning_queries.ProjectionCard {
  inventory_planning_queries.projection_card_new(
    card.card_type,
    card.collector_number,
    card.color_identity,
    card.name,
    card.quantity,
    card.rarity,
    card.set_code,
  )
}

pub fn map_upsert_inventory_rule_result(
  result: Result(Nil, upsert_rule_ports.UpsertInventoryRuleError),
) -> Result(
  inventory_planning_commands.UpsertInventoryRuleResponse,
  service.ServiceError,
) {
  case result {
    Ok(_) -> Ok(inventory_planning_commands.UpsertInventoryRuleResponseSuccess)
    Error(upsert_rule_ports.InvalidExpression) ->
      Error(service.ServiceError(
        service.E400xBadRequest,
        "invalid inventory rule expression",
      ))
    Error(upsert_rule_ports.InvalidSelector) ->
      Error(service.ServiceError(
        service.E400xBadRequest,
        "invalid inventory rule selector",
      ))
    Error(upsert_rule_ports.InvalidSortKeys) ->
      Error(service.ServiceError(
        service.E400xBadRequest,
        "invalid inventory rule sort keys",
      ))
    Error(upsert_rule_ports.PersistenceFailed(_)) ->
      Error(service.ServiceError(
        service.E500xInternalServerError,
        "failed to save inventory rule",
      ))
  }
}

pub fn map_update_bulk_spec_result(
  result: Result(Nil, update_bulk_spec_ports.UpdateBulkSpecError),
) -> Result(
  inventory_planning_commands.UpdateBulkSpecResponse,
  service.ServiceError,
) {
  case result {
    Ok(_) -> Ok(inventory_planning_commands.UpdateBulkSpecResponseSuccess)
    Error(update_bulk_spec_ports.InvalidSortKeys) ->
      Error(service.ServiceError(
        service.E400xBadRequest,
        "invalid bulk sort keys",
      ))
    Error(update_bulk_spec_ports.PersistenceFailed(_)) ->
      Error(service.ServiceError(
        service.E500xInternalServerError,
        "failed to save bulk spec",
      ))
  }
}

pub fn map_delete_inventory_rule_result(
  result: Result(Nil, delete_rule_ports.DeleteInventoryRuleError),
) -> Result(
  inventory_planning_commands.DeleteInventoryRuleResponse,
  service.ServiceError,
) {
  case result {
    Ok(_) -> Ok(inventory_planning_commands.DeleteInventoryRuleResponseSuccess)
    Error(_) ->
      Error(service.ServiceError(
        service.E500xInternalServerError,
        "failed to delete inventory rule",
      ))
  }
}

pub fn map_placed_ledger(
  rows: List(placed_ledger_ports.PlacedLedgerRow),
) -> inventory_planning_queries.PlacedLedger {
  inventory_planning_queries.placed_ledger_new(list.map(
    rows,
    map_placed_ledger_row,
  ))
}

fn map_placed_ledger_row(
  row: placed_ledger_ports.PlacedLedgerRow,
) -> inventory_planning_queries.PlacedLedgerRow {
  inventory_planning_queries.placed_ledger_row_new(
    row.collector_number,
    row.location,
    row.quantity,
    row.set_code,
  )
}

pub fn map_mark_cards_placed_result(
  result: Result(Nil, mark_cards_placed_ports.MarkCardsPlacedError),
) -> Result(
  inventory_planning_commands.MarkCardsPlacedResponse,
  service.ServiceError,
) {
  case result {
    Ok(_) -> Ok(inventory_planning_commands.MarkCardsPlacedResponseSuccess)
    Error(mark_cards_placed_ports.InvalidPlacements) ->
      Error(service.ServiceError(service.E400xBadRequest, "invalid placements"))
    Error(mark_cards_placed_ports.PersistenceFailed(_)) ->
      Error(service.ServiceError(
        service.E500xInternalServerError,
        "failed to mark cards placed",
      ))
  }
}

pub fn map_unmark_cards_placed_result(
  result: Result(Nil, unmark_cards_placed_ports.UnmarkCardsPlacedError),
) -> Result(
  inventory_planning_commands.UnmarkCardsPlacedResponse,
  service.ServiceError,
) {
  case result {
    Ok(_) -> Ok(inventory_planning_commands.UnmarkCardsPlacedResponseSuccess)
    Error(unmark_cards_placed_ports.InvalidPlacements) ->
      Error(service.ServiceError(service.E400xBadRequest, "invalid placements"))
    Error(unmark_cards_placed_ports.PersistenceFailed(_)) ->
      Error(service.ServiceError(
        service.E500xInternalServerError,
        "failed to unmark cards placed",
      ))
  }
}

pub fn map_update_preferences_result(
  result: Result(Nil, update_preferences_ports.UpdatePlanningPreferencesError),
) -> Result(
  inventory_planning_commands.UpdatePlanningPreferencesResponse,
  service.ServiceError,
) {
  case result {
    Ok(_) ->
      Ok(inventory_planning_commands.UpdatePlanningPreferencesResponseSuccess)
    Error(update_preferences_ports.InvalidPreferences) ->
      Error(service.ServiceError(service.E400xBadRequest, "invalid settings"))
    Error(update_preferences_ports.PersistenceFailed(_)) ->
      Error(service.ServiceError(
        service.E500xInternalServerError,
        "failed to save settings",
      ))
  }
}
