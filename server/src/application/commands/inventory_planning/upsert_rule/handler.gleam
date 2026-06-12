import application/commands/command_result
import application/commands/inventory_planning/upsert_rule/ports
import gleam/string

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

  case is_valid_rule_expression(expression) {
    False -> Error(ports.InvalidExpression)
    True -> {
      port.upsert_rule(ports.InventoryRuleWriteModel(
        id: id,
        location_name: location_name,
        expression: expression,
      ))
      Ok(Nil)
    }
  }
}

fn is_valid_rule_expression(expression: String) -> Bool {
  case string.split(expression, "=") {
    ["set_code", value] -> string.length(value) > 0
    _ -> False
  }
}
