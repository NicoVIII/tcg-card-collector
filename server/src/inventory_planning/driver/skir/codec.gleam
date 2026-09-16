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
    query_finish_from_string(card.finish),
    query_language_from_string(card.language),
    card.name,
    card.quantity,
    card.rarity,
    card.set_code,
  )
}

// Every wire enum used at this boundary is validated downstream (copy_key's
// constructors): an unrecognized incoming variant maps to an empty string,
// which fails validation and rejects the whole placement.
fn command_finish_to_string(
  value: inventory_planning_commands.Finish,
) -> String {
  case value {
    inventory_planning_commands.FinishNonfoil -> "nonfoil"
    inventory_planning_commands.FinishFoil -> "foil"
    inventory_planning_commands.FinishEtched -> "etched"
    inventory_planning_commands.FinishUnknown(_) -> ""
  }
}

fn command_language_to_string(
  value: inventory_planning_commands.Language,
) -> String {
  case value {
    inventory_planning_commands.LanguageEn -> "en"
    inventory_planning_commands.LanguageEs -> "es"
    inventory_planning_commands.LanguageFr -> "fr"
    inventory_planning_commands.LanguageDe -> "de"
    inventory_planning_commands.LanguageIt -> "it"
    inventory_planning_commands.LanguagePt -> "pt"
    inventory_planning_commands.LanguageJa -> "ja"
    inventory_planning_commands.LanguageKo -> "ko"
    inventory_planning_commands.LanguageRu -> "ru"
    inventory_planning_commands.LanguageZhs -> "zhs"
    inventory_planning_commands.LanguageZht -> "zht"
    inventory_planning_commands.LanguageHe -> "he"
    inventory_planning_commands.LanguageLa -> "la"
    inventory_planning_commands.LanguageGrc -> "grc"
    inventory_planning_commands.LanguageAr -> "ar"
    inventory_planning_commands.LanguageSa -> "sa"
    inventory_planning_commands.LanguagePh -> "ph"
    inventory_planning_commands.LanguageQya -> "qya"
    inventory_planning_commands.LanguageUnknown(_) -> ""
  }
}

fn query_finish_from_string(raw: String) -> inventory_planning_queries.Finish {
  case raw {
    "nonfoil" -> inventory_planning_queries.FinishNonfoil
    "foil" -> inventory_planning_queries.FinishFoil
    "etched" -> inventory_planning_queries.FinishEtched
    _ -> inventory_planning_queries.finish_unknown
  }
}

fn query_language_from_string(
  raw: String,
) -> inventory_planning_queries.Language {
  case raw {
    "en" -> inventory_planning_queries.LanguageEn
    "es" -> inventory_planning_queries.LanguageEs
    "fr" -> inventory_planning_queries.LanguageFr
    "de" -> inventory_planning_queries.LanguageDe
    "it" -> inventory_planning_queries.LanguageIt
    "pt" -> inventory_planning_queries.LanguagePt
    "ja" -> inventory_planning_queries.LanguageJa
    "ko" -> inventory_planning_queries.LanguageKo
    "ru" -> inventory_planning_queries.LanguageRu
    "zhs" -> inventory_planning_queries.LanguageZhs
    "zht" -> inventory_planning_queries.LanguageZht
    "he" -> inventory_planning_queries.LanguageHe
    "la" -> inventory_planning_queries.LanguageLa
    "grc" -> inventory_planning_queries.LanguageGrc
    "ar" -> inventory_planning_queries.LanguageAr
    "sa" -> inventory_planning_queries.LanguageSa
    "ph" -> inventory_planning_queries.LanguagePh
    "qya" -> inventory_planning_queries.LanguageQya
    _ -> inventory_planning_queries.language_unknown
  }
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
    query_finish_from_string(row.finish),
    query_language_from_string(row.language),
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
    finish: command_finish_to_string(placement.finish),
    language: command_language_to_string(placement.language),
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
    finish: command_finish_to_string(placement.finish),
    language: command_language_to_string(placement.language),
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
