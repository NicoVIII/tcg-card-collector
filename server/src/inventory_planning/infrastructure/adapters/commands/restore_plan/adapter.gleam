import gleam/dict
import gleam/list
import gleam/option
import inventory_planning/application/commands/restore_plan/ports
import inventory_planning/domain/location_ref
import inventory_planning/domain/managed_location
import inventory_planning/infrastructure/daos/inventory_rules_dao
import inventory_planning/infrastructure/daos/managed_locations_dao
import inventory_planning/infrastructure/daos/placed_cards_dao
import inventory_planning/infrastructure/daos/plan_dao
import shared/domain/copy_key

pub fn new() -> ports.RestorePlanPorts {
  ports.RestorePlanPorts(
    replace_plan: fn(rules, bulk, managed, placed) {
      plan_dao.replace(
        option.map(rules, list.map(_, to_rule_row)),
        option.map(bulk, to_bulk_row),
        option.map(managed, to_managed_rows),
        option.map(placed, list.map(_, to_placed_row)),
      )
    },
    list_managed_locations: managed_locations_dao.load_all,
  )
}

fn to_managed_rows(
  locations: List(managed_location.ManagedLocation),
) -> #(
  List(managed_locations_dao.ManagedLocationRow),
  List(managed_locations_dao.MemberRow),
) {
  #(
    list.map(locations, fn(location) {
      managed_locations_dao.ManagedLocationRow(
        id: location.id,
        name: location.name,
        kind: managed_location.kind_to_string(location.kind),
      )
    }),
    list.flat_map(locations, fn(location) {
      location.members
      |> dict.to_list
      |> list.map(fn(member) {
        managed_locations_dao.member_row(
          location.id,
          managed_location.MemberDelta(key: member.0, quantity: member.1),
        )
      })
    }),
  )
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
    location_kind: location_ref.kind_string(model.location),
    location: location_ref.key_string(model.location),
    quantity: model.quantity,
  )
}
