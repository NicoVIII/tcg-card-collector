import inventory_planning/application/commands/upsert_rule/ports
import inventory_planning/domain/rule_expression
import shared/application/command_result

pub type UpsertInventoryRuleCommand {
  UpsertInventoryRuleCommand(
    id: String,
    location_name: String,
    expression: String,
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
  ) = command

  case rule_expression.parse(expression) {
    Error(_) -> Error(ports.InvalidExpression)
    Ok(_) -> {
      port.upsert_rule(ports.InventoryRuleWriteModel(
        id: id,
        location_name: location_name,
        expression: expression,
      ))
      Ok(Nil)
    }
  }
}
