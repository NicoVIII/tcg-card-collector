import application/commands/command_result
import application/commands/inventory_planning/delete_rule/ports

pub type DeleteInventoryRuleCommand {
  DeleteInventoryRuleCommand(id: String)
}

pub fn execute(
  command: DeleteInventoryRuleCommand,
  port: ports.DeleteInventoryRulePort,
) -> command_result.CommandResult(ports.DeleteInventoryRuleError) {
  let DeleteInventoryRuleCommand(id: id) = command
  port.delete_rule(id)
  Ok(Nil)
}
