import gleam/bool
import gleam/result
import gleam/string
import inventory_planning/application/commands/create_managed_location/ports
import inventory_planning/domain/managed_location
import shared/application/command_result

/// The id is client-generated (a UUID), the same as a rule's.
pub type CreateManagedLocationCommand {
  CreateManagedLocationCommand(id: String, name: String, kind: String)
}

pub fn execute(
  command: CreateManagedLocationCommand,
  ports: ports.CreateManagedLocationPorts,
) -> command_result.CommandResult(ports.CreateManagedLocationError) {
  let id = string.trim(command.id)
  use <- bool.guard(id == "", Error(ports.InvalidId))
  use name <- result.try(
    managed_location.parse_name(command.name)
    |> result.replace_error(ports.InvalidName),
  )
  use kind <- result.try(
    managed_location.kind_from_string(command.kind)
    |> result.replace_error(ports.InvalidKind),
  )
  use existing <- result.try(
    ports.list_locations() |> result.map_error(ports.PersistenceFailed),
  )
  use <- bool.guard(
    result.is_ok(managed_location.find(existing, id)),
    Error(ports.DuplicateId),
  )
  use <- bool.guard(
    managed_location.name_taken(existing, name, except_id: id),
    Error(ports.DuplicateName),
  )

  ports.insert(ports.ManagedLocationWriteModel(id:, name:, kind:))
  |> result.map_error(ports.PersistenceFailed)
}
