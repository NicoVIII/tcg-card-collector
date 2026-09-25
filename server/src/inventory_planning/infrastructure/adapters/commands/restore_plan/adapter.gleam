import gleam/list
import gleam/option
import inventory_planning/application/commands/restore_plan/ports
import inventory_planning/infrastructure/daos/inventory_rules_dao
import inventory_planning/infrastructure/daos/placed_cards_dao
import inventory_planning/infrastructure/daos/plan_dao
import shared/domain/copy_key

pub fn new() -> ports.RestorePlanPorts {
  ports.RestorePlanPorts(replace_plan: fn(rules, bulk, placed) {
    plan_dao.replace(
      option.map(rules, list.map(_, to_rule_row)),
      option.map(bulk, to_bulk_row),
      option.map(placed, list.map(_, to_placed_row)),
    )
  })
}

fn to_rule_row(rule: ports.RuleWriteModel) -> inventory_rules_dao.RuleRow {
  inventory_rules_dao.RuleRow(
    id: rule.id,
    location_name: rule.location_name,
    expression: rule.expression,
    position: rule.position,
    selector: rule.selector,
    sort_keys: rule.sort_keys,
  )
}

fn to_bulk_row(spec: ports.BulkSpecWriteModel) -> #(String, String) {
  #(spec.location_name, spec.sort_keys)
}

fn to_placed_row(
  model: ports.PlacedWriteModel,
) -> placed_cards_dao.PlacedCardRow {
  placed_cards_dao.PlacedCardRow(
    set_code: copy_key.set_code_string(model.key),
    collector_number: copy_key.collector_number_string(model.key),
    finish: copy_key.finish_string(model.key),
    language: copy_key.language_string(model.key),
    location: model.location,
    quantity: model.quantity,
  )
}
