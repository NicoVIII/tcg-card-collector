import gleam/string
import inventory_planning/application/commands/mark_cards_placed/handler
import inventory_planning/application/commands/mark_cards_placed/ports

// Echoes the write models it was handed back through the (otherwise unused)
// error channel, so a test asserts the exact normalized batch that reached the
// port rather than merely that the port was called.
fn capturing_port() -> ports.MarkCardsPlacedPort {
  fn(models) { Error(string.inspect(models)) }
}

fn command(
  placements: List(handler.RawPlacement),
) -> handler.MarkCardsPlacedCommand {
  handler.MarkCardsPlacedCommand(placements: placements)
}

fn raw(
  set_code set_code: String,
  collector_number collector_number: String,
  location_name location_name: String,
  quantity quantity: Int,
) -> handler.RawPlacement {
  handler.RawPlacement(
    set_code:,
    collector_number:,
    finish: "nonfoil",
    language: "en",
    location_name:,
    quantity:,
  )
}

fn write_model(
  set_code set_code: String,
  collector_number collector_number: String,
  location location: String,
  quantity quantity: Int,
) -> ports.PlacementWriteModel {
  ports.PlacementWriteModel(
    set_code:,
    collector_number:,
    finish: "nonfoil",
    language: "en",
    location:,
    quantity:,
  )
}

pub fn normalized_and_merged_batch_reaches_the_port_test() {
  // Set codes lowercase, collector numbers trim; duplicate (key, location) sums;
  // the batch arrives sorted by key then location.
  let placements = [
    raw(
      set_code: "LEA",
      collector_number: "2",
      location_name: "Bulk",
      quantity: 1,
    ),
    raw(
      set_code: "lea",
      collector_number: "1",
      location_name: "Bulk",
      quantity: 2,
    ),
    raw(
      set_code: "lea",
      collector_number: "1",
      location_name: "Bulk",
      quantity: 3,
    ),
  ]

  let expected = [
    write_model(
      set_code: "lea",
      collector_number: "1",
      location: "Bulk",
      quantity: 5,
    ),
    write_model(
      set_code: "lea",
      collector_number: "2",
      location: "Bulk",
      quantity: 1,
    ),
  ]

  assert handler.execute(command(placements), capturing_port())
    == Error(ports.PersistenceFailed(string.inspect(expected)))
}

// Same printing and location, different finish: the port sees two write
// models, not one summed row (ADR 0010).
pub fn different_finish_stays_a_separate_write_model_test() {
  let placements = [
    handler.RawPlacement(
      set_code: "lea",
      collector_number: "1",
      finish: "nonfoil",
      language: "en",
      location_name: "Bulk",
      quantity: 2,
    ),
    handler.RawPlacement(
      set_code: "lea",
      collector_number: "1",
      finish: "foil",
      language: "en",
      location_name: "Bulk",
      quantity: 1,
    ),
  ]

  let expected = [
    ports.PlacementWriteModel(
      set_code: "lea",
      collector_number: "1",
      finish: "foil",
      language: "en",
      location: "Bulk",
      quantity: 1,
    ),
    ports.PlacementWriteModel(
      set_code: "lea",
      collector_number: "1",
      finish: "nonfoil",
      language: "en",
      location: "Bulk",
      quantity: 2,
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
    raw(
      set_code: "lea",
      collector_number: "1",
      location_name: "Bulk",
      quantity: 1,
    ),
    raw(
      set_code: "lea",
      collector_number: "2",
      location_name: "Bulk",
      quantity: 0,
    ),
  ]

  assert handler.execute(command(placements), capturing_port())
    == Error(ports.InvalidPlacements)
}

pub fn empty_location_is_rejected_test() {
  let placements = [
    raw(set_code: "lea", collector_number: "1", location_name: "", quantity: 1),
  ]

  assert handler.execute(command(placements), capturing_port())
    == Error(ports.InvalidPlacements)
}

pub fn port_failure_surfaces_as_persistence_failed_test() {
  let placements = [
    raw(
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
