import gleam/result
import insights/application/commands/mark_target_set/ports
import insights/domain/target_set
import shared/application/command_result

pub type MarkTargetSetCommand {
  MarkTargetSetCommand(set_code: String)
}

pub fn execute(
  command: MarkTargetSetCommand,
  port: ports.MarkTargetSetPort,
) -> command_result.CommandResult(ports.MarkTargetSetError) {
  case target_set.parse(command.set_code) {
    Error(Nil) -> Error(ports.InvalidSetCode)
    Ok(target) ->
      port.mark(target_set.to_string(target))
      |> result.map_error(ports.PersistenceFailed)
  }
}
