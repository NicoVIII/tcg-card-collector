import gleam/dict
import gleam/option.{type Option, None, Some}
import inventory_planning/application/commands/delete_managed_location/handler
import inventory_planning/application/commands/delete_managed_location/ports
import inventory_planning/domain/managed_location.{Deck, ManagedLocation}
import support/ref

fn delete(id: String) {
  let written: ref.Ref(Option(String)) = ref.new(None)
  let result =
    handler.execute(
      handler.DeleteManagedLocationCommand(id:),
      ports.DeleteManagedLocationPorts(
        list_locations: fn() {
          Ok([ManagedLocation("d1", "Burn", Deck, dict.new())])
        },
        delete: fn(id) {
          ref.set(written, Some(id))
          Ok(Nil)
        },
      ),
    )
  #(result, ref.get(written))
}

pub fn deleting_a_known_deck_reaches_the_port_test() {
  assert delete("d1") == #(Ok(Nil), Some("d1"))
}

pub fn deleting_an_unknown_deck_is_an_error_not_a_no_op_test() {
  assert delete("nope") == #(Error(ports.UnknownLocation), None)
}
