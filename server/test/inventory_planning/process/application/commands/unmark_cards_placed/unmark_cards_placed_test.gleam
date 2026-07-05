import gleam/string
import inventory_planning/application/commands/unmark_cards_placed/handler
import inventory_planning/application/commands/unmark_cards_placed/ports

// Echoes the write models it was handed back through the (otherwise unused)
// error channel, so a test asserts the exact normalized batch that reached the
// port rather than merely that the port was called.
fn capturing_port() -> ports.UnmarkCardsPlacedPort {
  fn(models) { Error(string.inspect(models)) }
}

fn command(
  placements: List(handler.RawPlacement),
) -> handler.UnmarkCardsPlacedCommand {
  handler.UnmarkCardsPlacedCommand(placements: placements)
}

pub fn normalized_and_merged_batch_reaches_the_port_test() {
  let placements = [
    handler.RawPlacement(
      set_code: "LEA",
      collector_number: "1",
      location_name: "Bulk",
      quantity: 2,
    ),
    handler.RawPlacement(
      set_code: "lea",
      collector_number: "1",
      location_name: "Bulk",
      quantity: 1,
    ),
  ]

  let expected = [
    ports.PlacementWriteModel(
      set_code: "lea",
      collector_number: "1",
      location: "Bulk",
      quantity: 3,
    ),
  ]

  assert handler.execute(command(placements), capturing_port())
    == Error(ports.PersistenceFailed(string.inspect(expected)))
}

pub fn empty_batch_is_rejected_test() {
  assert handler.execute(command([]), capturing_port())
    == Error(ports.InvalidPlacements)
}

pub fn invalid_placement_rejects_the_whole_batch_test() {
  let placements = [
    handler.RawPlacement(
      set_code: "lea",
      collector_number: "1",
      location_name: "Bulk",
      quantity: 1,
    ),
    handler.RawPlacement(
      set_code: "",
      collector_number: "2",
      location_name: "Bulk",
      quantity: 1,
    ),
  ]

  assert handler.execute(command(placements), capturing_port())
    == Error(ports.InvalidPlacements)
}

pub fn port_failure_surfaces_as_persistence_failed_test() {
  let placements = [
    handler.RawPlacement(
      set_code: "lea",
      collector_number: "1",
      location_name: "Bulk",
      quantity: 1,
    ),
  ]
  let failing_port = fn(_models) { Error("db down") }

  assert handler.execute(command(placements), failing_port)
    == Error(ports.PersistenceFailed("db down"))
}
