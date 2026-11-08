import gleam/list
import gleam/result
import inventory_planning/application/commands/add_to_managed_location/ports
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

pub type AddToManagedLocationCommand {
  AddToManagedLocationCommand(id: String, copies: List(RawCopy))
}

/// Rejects the whole batch if any key would be claimed beyond what's owned
/// across every managed location (ADR 0022) — the client knows owned and
/// claimed quantities, so a rejection means a stale page, not a choice the
/// server makes for the user.
pub fn execute(
  command: AddToManagedLocationCommand,
  ports: ports.AddToManagedLocationPorts,
) -> command_result.CommandResult(ports.AddToManagedLocationError) {
  use deltas <- result.try(parse_copies(command.copies))
  use existing <- result.try(
    ports.list_locations() |> result.map_error(ports.PersistenceFailed),
  )
  use _ <- result.try(
    managed_location.find(existing, command.id)
    |> result.replace_error(ports.UnknownLocation),
  )
  use owned <- result.try(
    ports.owned_quantities() |> result.map_error(ports.PersistenceFailed),
  )
  use _ <- result.try(
    managed_location.check_addition(
      deltas,
      owned:,
      claimed: managed_location.claimed_totals(existing),
    )
    |> result.map_error(ports.NotEnoughOwned),
  )

  ports.increment_members(command.id, deltas)
  |> result.map_error(ports.PersistenceFailed)
}

// An empty batch is a malformed request, not a no-op.
fn parse_copies(
  copies: List(RawCopy),
) -> Result(List(managed_location.MemberDelta), ports.AddToManagedLocationError) {
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
