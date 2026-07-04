import gleam/result
import insights/application/commands/unmark_target_set/ports
import insights/domain/target_set
import shared/application/command_result

pub type UnmarkTargetSetCommand {
  UnmarkTargetSetCommand(set_code: String)
}

pub fn execute(
  command: UnmarkTargetSetCommand,
  port: ports.UnmarkTargetSetPort,
) -> command_result.CommandResult(ports.UnmarkTargetSetError) {
  case target_set.parse(command.set_code) {
    Error(Nil) -> Error(ports.InvalidSetCode)
    Ok(target) ->
      port.unmark(target_set.to_string(target))
      |> result.map_error(ports.PersistenceFailed)
  }
}
