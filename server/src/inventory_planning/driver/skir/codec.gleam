import gleam/list
import inventory_planning/application/commands/delete_rule/ports as delete_rule_ports
import inventory_planning/application/commands/mark_cards_placed/handler as mark_cards_placed_handler
import inventory_planning/application/commands/mark_cards_placed/ports as mark_cards_placed_ports
import inventory_planning/application/commands/unmark_cards_placed/handler as unmark_cards_placed_handler
import inventory_planning/application/commands/unmark_cards_placed/ports as unmark_cards_placed_ports
import inventory_planning/application/commands/update_bulk_spec/ports as update_bulk_spec_ports
import inventory_planning/application/commands/upsert_rule/ports as upsert_rule_ports
import inventory_planning/application/queries/get_bulk_spec/ports as get_bulk_spec_ports
import inventory_planning/application/queries/list_rules/ports as list_rules_ports
import inventory_planning/application/queries/placed_ledger/ports as placed_ledger_ports
import inventory_planning/application/queries/projection/ports as projection_ports
import inventory_planning/driver/error_presentation
import shared/driver/skir/helpers
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
  helpers.map_command(
    result,
    inventory_planning_commands.UpsertInventoryRuleResponseSuccess,
    error_presentation.upsert_rule,
  )
}

pub fn map_update_bulk_spec_result(
  result: Result(Nil, update_bulk_spec_ports.UpdateBulkSpecError),
) -> Result(
  inventory_planning_commands.UpdateBulkSpecResponse,
  service.ServiceError,
) {
  helpers.map_command(
    result,
    inventory_planning_commands.UpdateBulkSpecResponseSuccess,
    error_presentation.update_bulk_spec,
  )
}

pub fn map_delete_inventory_rule_result(
  result: Result(Nil, delete_rule_ports.DeleteInventoryRuleError),
) -> Result(
  inventory_planning_commands.DeleteInventoryRuleResponse,
  service.ServiceError,
) {
  helpers.map_command(
    result,
    inventory_planning_commands.DeleteInventoryRuleResponseSuccess,
    error_presentation.delete_rule,
  )
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
  helpers.map_command(
    result,
    inventory_planning_commands.MarkCardsPlacedResponseSuccess,
    error_presentation.mark_cards_placed,
  )
}

pub fn map_unmark_cards_placed_result(
  result: Result(Nil, unmark_cards_placed_ports.UnmarkCardsPlacedError),
) -> Result(
  inventory_planning_commands.UnmarkCardsPlacedResponse,
  service.ServiceError,
) {
  helpers.map_command(
    result,
    inventory_planning_commands.UnmarkCardsPlacedResponseSuccess,
    error_presentation.unmark_cards_placed,
  )
}

pub fn to_mark_raw_placement(
  placement: inventory_planning_commands.CardPlacement,
) -> mark_cards_placed_handler.RawPlacement {
  mark_cards_placed_handler.RawPlacement(
    set_code: placement.set_code,
    collector_number: placement.collector_number,
    location_name: placement.location_name,
    quantity: placement.quantity,
  )
}

pub fn to_unmark_raw_placement(
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
    rule.sort_keys,
  )
}

pub fn map_inventory_rule_list(
  rules: List(list_rules_ports.InventoryRuleReadModel),
) -> inventory_planning_queries.InventoryRuleList {
  inventory_planning_queries.inventory_rule_list_new(
    list.map(rules, map_inventory_rule),
    list.length(rules),
  )
}

pub fn map_bulk_spec(
  spec: get_bulk_spec_ports.BulkSpecReadModel,
) -> inventory_planning_queries.BulkSpec {
  inventory_planning_queries.bulk_spec_new(spec.location_name, spec.sort_keys)
}
