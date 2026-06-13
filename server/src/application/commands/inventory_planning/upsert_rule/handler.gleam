import application/commands/command_result
import application/commands/inventory_planning/upsert_rule/ports
import domain/inventory_planning/rule_expression

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
