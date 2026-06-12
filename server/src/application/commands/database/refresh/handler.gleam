import application/commands/command_result
import application/commands/database/refresh/ports

pub type RefreshDatabaseCommand {
  RefreshDatabaseCommand
}

pub fn execute(
  _command: RefreshDatabaseCommand,
  port: ports.RefreshDatabasePort,
) -> command_result.CommandResult(ports.RefreshDatabaseError) {
  port.execute()
}
