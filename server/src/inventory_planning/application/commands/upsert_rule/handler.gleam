import gleam/result
import inventory_planning/application/commands/upsert_rule/ports
import inventory_planning/domain/card_predicate
import inventory_planning/domain/copy_selector
import shared/application/command_result

pub type UpsertInventoryRuleCommand {
  UpsertInventoryRuleCommand(
    id: String,
    location_name: String,
    expression: String,
    position: Int,
    selector: String,
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
  ) = command

  // The location string doubles as a fan-out template; location_target.parse
  // treats any string as valid (plain name = degenerate template), so it needs
  // no validation here — only the predicate and selector can be malformed.
  use selector <- result.try(
    copy_selector.parse(selector)
    |> result.replace_error(ports.InvalidSelector),
  )
  use predicate <- result.try(
    card_predicate.parse(expression)
    |> result.replace_error(ports.InvalidExpression),
  )

  port.upsert_rule(ports.InventoryRuleWriteModel(
    id: id,
    location_name: location_name,
    expression: card_predicate.to_string(predicate),
    position: position,
    selector: copy_selector.to_string(selector),
  ))
  |> result.map_error(ports.PersistenceFailed)
}
