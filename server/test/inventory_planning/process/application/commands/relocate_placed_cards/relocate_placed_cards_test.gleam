import gleam/string
import inventory_planning/application/commands/relocate_placed_cards/handler
import inventory_planning/application/commands/relocate_placed_cards/ports

// Echoes the write model it was handed back through the (otherwise unused)
// error channel, so a test asserts the exact normalized relocation that
// reached the port rather than merely that the port was called.
fn capturing_port() -> ports.RelocatePlacedCardsPort {
  fn(model) { Error(string.inspect(model)) }
}

fn command(
  from_location from_location: String,
  to_location to_location: String,
) -> handler.RelocatePlacedCardsCommand {
  handler.RelocatePlacedCardsCommand(from_location:, to_location:)
}

pub fn trimmed_relocation_reaches_the_port_test() {
  let expected = ports.RelocationWriteModel(from: "Box 1", to: "Binder A")

  assert handler.execute(
      command(from_location: " Box 1 ", to_location: " Binder A "),
      capturing_port(),
    )
    == Error(ports.PersistenceFailed(string.inspect(expected)))
}

pub fn empty_from_location_is_rejected_test() {
  assert handler.execute(
      command(from_location: "", to_location: "Binder A"),
      capturing_port(),
    )
    == Error(ports.InvalidRelocation)
}

pub fn empty_to_location_is_rejected_test() {
  assert handler.execute(
      command(from_location: "Box 1", to_location: ""),
      capturing_port(),
    )
    == Error(ports.InvalidRelocation)
}

pub fn same_location_is_rejected_test() {
  assert handler.execute(
      command(from_location: "Box 1", to_location: "Box 1"),
      capturing_port(),
    )
    == Error(ports.InvalidRelocation)
}

// Trimming can make two textually-different requests collide on the same
// location — the same case as `SameLocation`, and must be rejected the same
// way, not silently pass a blank relocation to the port.
pub fn same_location_after_trim_is_rejected_test() {
  assert handler.execute(
      command(from_location: "Box 1 ", to_location: " Box 1"),
      capturing_port(),
    )
    == Error(ports.InvalidRelocation)
}

pub fn port_failure_surfaces_as_persistence_failed_test() {
  let failing_port = fn(_model) { Error("db down") }

  assert handler.execute(
      command(from_location: "Box 1", to_location: "Binder A"),
      failing_port,
    )
    == Error(ports.PersistenceFailed("db down"))
}
