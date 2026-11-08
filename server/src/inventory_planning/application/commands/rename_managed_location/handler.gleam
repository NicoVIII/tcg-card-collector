import gleam/bool
import gleam/result
import inventory_planning/application/commands/rename_managed_location/ports
import inventory_planning/domain/managed_location
import shared/application/command_result

pub type RenameManagedLocationCommand {
  RenameManagedLocationCommand(id: String, name: String)
}

/// Changes only the display name: ledger rows key on the id, so nothing
/// placed there strands (ADR 0022).
pub fn execute(
  command: RenameManagedLocationCommand,
  ports: ports.RenameManagedLocationPorts,
) -> command_result.CommandResult(ports.RenameManagedLocationError) {
  use name <- result.try(
    managed_location.parse_name(command.name)
    |> result.replace_error(ports.InvalidName),
  )
  use existing <- result.try(
    ports.list_locations() |> result.map_error(ports.PersistenceFailed),
  )
  use _ <- result.try(
    managed_location.find(existing, command.id)
    |> result.replace_error(ports.UnknownLocation),
  )
  use <- bool.guard(
    managed_location.name_taken(existing, name, except_id: command.id),
    Error(ports.DuplicateName),
  )

  ports.rename(command.id, name)
  |> result.map_error(ports.PersistenceFailed)
}
