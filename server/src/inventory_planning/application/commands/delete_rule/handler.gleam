import inventory_planning/application/commands/delete_rule/ports
import shared/application/command_result

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
