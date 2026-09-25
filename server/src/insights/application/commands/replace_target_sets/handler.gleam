import gleam/list
import gleam/result
import insights/application/commands/replace_target_sets/ports
import insights/domain/target_set
import shared/application/command_result

pub type ReplaceTargetSetsCommand {
  ReplaceTargetSetsCommand(set_codes: List(String))
}

/// All-or-nothing, like ImportCollection: replacing target sets states the
/// whole set of targets, so one invalid code rejects the request rather
/// than silently dropping it. Portability's import already pre-filters
/// codes at the document level before calling this (ADR 0019), so this
/// validation is defense-in-depth, not a caller-facing filter — an empty
/// list is valid and clears every target.
pub fn execute(
  command: ReplaceTargetSetsCommand,
  port: ports.ReplaceTargetSetsPort,
) -> command_result.CommandResult(ports.ReplaceTargetSetsError) {
  let ReplaceTargetSetsCommand(set_codes: set_codes) = command

  case list.try_map(set_codes, target_set.parse) {
    Error(Nil) -> Error(ports.InvalidSetCodes)
    Ok(targets) ->
      port.replace(list.map(targets, target_set.to_string))
      |> result.map_error(ports.PersistenceFailed)
  }
}
