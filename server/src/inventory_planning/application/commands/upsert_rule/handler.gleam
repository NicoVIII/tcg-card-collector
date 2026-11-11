import gleam/result
import inventory_planning/application/commands/upsert_rule/ports
import inventory_planning/domain/card_predicate
import inventory_planning/domain/copy_selector
import inventory_planning/domain/location_ref
import inventory_planning/domain/sort_spec
import shared/application/command_result

pub type UpsertInventoryRuleCommand {
  UpsertInventoryRuleCommand(
    id: String,
    location_name: String,
    expression: String,
    position: Int,
    selector: String,
    sort_keys: String,
  )
}

pub fn execute(
  command: UpsertInventoryRuleCommand,
  port: ports.UpsertInventoryRulePort,
) -> command_result.CommandResult(ports.UpsertInventoryRuleError) {
  let UpsertInventoryRuleCommand(
    id: id,
    location_name: location_name,
    expression: expression,
    position: position,
    selector: selector,
    sort_keys: sort_keys,
  ) = command

  // The location doubles as a fan-out template, so beyond being non-blank any
  // string is a valid target (a plain name is a degenerate template).
  use location_name <- result.try(
    location_ref.parse_cascade_name(location_name)
    |> result.replace_error(ports.InvalidLocationName),
  )
  use selector <- result.try(
    copy_selector.parse(selector)
    |> result.replace_error(ports.InvalidSelector),
  )
  use predicate <- result.try(
    card_predicate.parse(expression)
    |> result.replace_error(ports.InvalidExpression),
  )
  use sort_keys <- result.try(
    sort_spec.parse_sort_keys(sort_keys)
    |> result.replace_error(ports.InvalidSortKeys),
  )

  port.upsert_rule(ports.InventoryRuleWriteModel(
    id: id,
    location_name: location_name,
    expression: card_predicate.to_string(predicate),
    position: position,
    selector: copy_selector.to_string(selector),
    sort_keys: sort_spec.sort_keys_to_string(sort_keys),
  ))
  |> result.map_error(ports.PersistenceFailed)
}
