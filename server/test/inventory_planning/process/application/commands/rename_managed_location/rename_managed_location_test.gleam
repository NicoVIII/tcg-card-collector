import gleam/dict
import gleam/option.{type Option, None, Some}
import inventory_planning/application/commands/rename_managed_location/handler
import inventory_planning/application/commands/rename_managed_location/ports
import inventory_planning/domain/managed_location.{Deck, ManagedLocation}
import support/ref

fn rename(id: String, name: String) {
  let written: ref.Ref(Option(#(String, String))) = ref.new(None)
  let result =
    handler.execute(
      handler.RenameManagedLocationCommand(id:, name:),
      ports.RenameManagedLocationPorts(
        list_locations: fn() {
          Ok([
            ManagedLocation("d1", "Burn", Deck, dict.new()),
            ManagedLocation("d2", "Elves", Deck, dict.new()),
          ])
        },
        rename: fn(id, name) {
          ref.set(written, Some(#(id, name)))
          Ok(Nil)
        },
      ),
    )
  #(result, ref.get(written))
}

// Re-saving a deck under its own name isn't a clash with itself.
pub fn renaming_to_a_free_name_or_its_own_name_succeeds_test() {
  assert rename("d1", "Red Deck Wins")
    == #(Ok(Nil), Some(#("d1", "Red Deck Wins")))
  assert rename("d1", "Burn") == #(Ok(Nil), Some(#("d1", "Burn")))
}

pub fn renaming_to_another_decks_name_is_rejected_test() {
  assert rename("d1", "Elves") == #(Error(ports.DuplicateName), None)
}

pub fn renaming_an_unknown_location_is_rejected_test() {
  assert rename("nope", "Whatever") == #(Error(ports.UnknownLocation), None)
}
