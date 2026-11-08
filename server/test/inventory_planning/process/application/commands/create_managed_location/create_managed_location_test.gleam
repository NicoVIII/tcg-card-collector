import gleam/dict
import gleam/option.{type Option, None, Some}
import inventory_planning/application/commands/create_managed_location/handler
import inventory_planning/application/commands/create_managed_location/ports
import inventory_planning/domain/managed_location.{Deck, ManagedLocation}
import support/ref

fn create(id: String, name: String, kind: String) {
  let written = ref.new(None)
  let result =
    handler.execute(
      handler.CreateManagedLocationCommand(id:, name:, kind:),
      ports.CreateManagedLocationPorts(
        list_locations: fn() {
          Ok([ManagedLocation("d1", "Burn", Deck, dict.new())])
        },
        insert: fn(model) {
          ref.set(written, Some(model))
          Ok(Nil)
        },
      ),
    )
  let written: Option(ports.ManagedLocationWriteModel) = ref.get(written)
  #(result, written)
}

pub fn a_new_deck_is_inserted_with_its_name_trimmed_test() {
  assert create("d2", "  Elves ", "deck")
    == #(Ok(Nil), Some(ports.ManagedLocationWriteModel("d2", "Elves", Deck)))
}

pub fn a_duplicate_name_or_id_is_rejected_test() {
  assert create("d2", "Burn", "deck") == #(Error(ports.DuplicateName), None)
  assert create("d1", "Elves", "deck") == #(Error(ports.DuplicateId), None)
}

pub fn a_blank_name_id_or_unknown_kind_is_rejected_test() {
  assert create("d2", " ", "deck") == #(Error(ports.InvalidName), None)
  assert create(" ", "Elves", "deck") == #(Error(ports.InvalidId), None)
  assert create("d2", "Elves", "binder") == #(Error(ports.InvalidKind), None)
}
