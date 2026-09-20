import gleam/result
import inventory_planning/application/commands/relocate_placed_cards/ports
import inventory_planning/domain/placement
import shared/application/command_result

pub type RelocatePlacedCardsCommand {
  RelocatePlacedCardsCommand(from_location: String, to_location: String)
}

pub fn execute(
  command: RelocatePlacedCardsCommand,
  port: ports.RelocatePlacedCardsPort,
) -> command_result.CommandResult(ports.RelocatePlacedCardsError) {
  use relocation <- result.try(
    placement.new_relocation(
      from: command.from_location,
      to: command.to_location,
    )
    |> result.replace_error(ports.InvalidRelocation),
  )

  port(ports.RelocationWriteModel(
    from: placement.relocation_from(relocation),
    to: placement.relocation_to(relocation),
  ))
  |> result.map_error(ports.PersistenceFailed)
}
