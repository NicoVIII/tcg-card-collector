import gleam/result
import inventory_planning/application/commands/delete_managed_location/ports
import inventory_planning/domain/managed_location
import shared/application/command_result

pub type DeleteManagedLocationCommand {
  DeleteManagedLocationCommand(id: String)
}

/// Dismantling a deck: its placed-ledger rows go with it, so its copies
/// re-enter placement guidance at wherever the cascade now sends them
/// (ADR 0022). An unknown id is an error, not a no-op — the client only
/// offers delete for a location it listed.
pub fn execute(
  command: DeleteManagedLocationCommand,
  ports: ports.DeleteManagedLocationPorts,
) -> command_result.CommandResult(ports.DeleteManagedLocationError) {
  use existing <- result.try(
    ports.list_locations() |> result.map_error(ports.PersistenceFailed),
  )
  use _ <- result.try(
    managed_location.find(existing, command.id)
    |> result.replace_error(ports.UnknownLocation),
  )

  ports.delete(command.id)
  |> result.map_error(ports.PersistenceFailed)
}
