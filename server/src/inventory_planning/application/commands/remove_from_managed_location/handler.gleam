import gleam/list
import gleam/result
import inventory_planning/application/commands/remove_from_managed_location/ports
import inventory_planning/domain/managed_location
import shared/application/command_result

/// One kind of copy as it arrives on the wire, still raw.
pub type RawCopy {
  RawCopy(
    set_code: String,
    collector_number: String,
    finish: String,
    language: String,
    quantity: Int,
  )
}

pub type RemoveFromManagedLocationCommand {
  RemoveFromManagedLocationCommand(id: String, copies: List(RawCopy))
}

/// Removing more than the location holds rejects the whole batch rather than
/// clamping — the client shows what the location holds, so it means a stale
/// page (ADR 0021).
pub fn execute(
  command: RemoveFromManagedLocationCommand,
  ports: ports.RemoveFromManagedLocationPorts,
) -> command_result.CommandResult(ports.RemoveFromManagedLocationError) {
  use deltas <- result.try(parse_copies(command.copies))
  use existing <- result.try(
    ports.list_locations() |> result.map_error(ports.PersistenceFailed),
  )
  use location <- result.try(
    managed_location.find(existing, command.id)
    |> result.replace_error(ports.UnknownLocation),
  )
  use _ <- result.try(
    managed_location.check_removal(location, deltas)
    |> result.map_error(ports.NotHeld),
  )

  ports.decrement_members(command.id, deltas)
  |> result.map_error(ports.PersistenceFailed)
}

// An empty batch is a malformed request, not a no-op.
fn parse_copies(
  copies: List(RawCopy),
) -> Result(
  List(managed_location.MemberDelta),
  ports.RemoveFromManagedLocationError,
) {
  case copies {
    [] -> Error(ports.InvalidCopies)
    _ ->
      list.try_map(copies, fn(raw) {
        managed_location.delta_from_input(
          set_code: raw.set_code,
          collector_number: raw.collector_number,
          finish: raw.finish,
          language: raw.language,
          quantity: raw.quantity,
        )
      })
      |> result.map(managed_location.merge_deltas)
      |> result.replace_error(ports.InvalidCopies)
  }
}
