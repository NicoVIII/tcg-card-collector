import gleam/list
import gleam/result
import inventory_planning/application/commands/unmark_cards_placed/ports
import inventory_planning/domain/placement
import shared/application/command_result

// One placement as it arrives on the wire — every field still a raw string/int.
pub type RawPlacement {
  RawPlacement(
    set_code: String,
    collector_number: String,
    location_name: String,
    quantity: Int,
  )
}

pub type UnmarkCardsPlacedCommand {
  UnmarkCardsPlacedCommand(placements: List(RawPlacement))
}

pub fn execute(
  command: UnmarkCardsPlacedCommand,
  port: ports.UnmarkCardsPlacedPort,
) -> command_result.CommandResult(ports.UnmarkCardsPlacedError) {
  // An empty batch is a malformed request, not a no-op: reject it rather than
  // silently succeed on nothing.
  use <- guard_non_empty(command.placements)

  use placements <- result.try(
    list.try_map(command.placements, validate)
    |> result.replace_error(ports.InvalidPlacements),
  )

  placement.merge(placements)
  |> list.map(to_write_model)
  |> port
  |> result.map_error(ports.PersistenceFailed)
}

fn guard_non_empty(
  placements: List(RawPlacement),
  continue: fn() -> command_result.CommandResult(ports.UnmarkCardsPlacedError),
) -> command_result.CommandResult(ports.UnmarkCardsPlacedError) {
  case placements {
    [] -> Error(ports.InvalidPlacements)
    _ -> continue()
  }
}

fn validate(
  raw: RawPlacement,
) -> Result(placement.Placement, placement.PlacementError) {
  placement.new(
    set_code: raw.set_code,
    collector_number: raw.collector_number,
    location: raw.location_name,
    quantity: raw.quantity,
  )
}

fn to_write_model(p: placement.Placement) -> ports.PlacementWriteModel {
  ports.PlacementWriteModel(
    set_code: placement.set_code_string(p),
    collector_number: placement.collector_number_string(p),
    location: placement.location(p),
    quantity: placement.quantity(p),
  )
}
