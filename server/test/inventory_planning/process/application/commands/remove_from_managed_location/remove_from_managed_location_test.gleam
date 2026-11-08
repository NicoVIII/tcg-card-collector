import gleam/dict
import gleam/option.{type Option, None, Some}
import inventory_planning/application/commands/remove_from_managed_location/handler
import inventory_planning/application/commands/remove_from_managed_location/ports
import inventory_planning/domain/managed_location.{
  type MemberDelta, Deck, ManagedLocation, MemberDelta, Underheld,
}
import shared/domain/copy_key.{type CopyKey}
import support/ref

fn key(collector_number: String) -> CopyKey {
  let assert Ok(key) =
    copy_key.new(
      set_code: "lea",
      collector_number:,
      finish: "nonfoil",
      language: "en",
    )
  key
}

fn remove(id: String, quantity: Int) {
  let written: ref.Ref(Option(#(String, List(MemberDelta)))) = ref.new(None)
  let result =
    handler.execute(
      handler.RemoveFromManagedLocationCommand(id:, copies: [
        handler.RawCopy(
          set_code: "lea",
          collector_number: "1",
          finish: "nonfoil",
          language: "en",
          quantity:,
        ),
      ]),
      ports.RemoveFromManagedLocationPorts(
        list_locations: fn() {
          Ok([
            ManagedLocation(
              "d1",
              "Burn",
              Deck,
              dict.from_list([#(key("1"), 2)]),
            ),
          ])
        },
        decrement_members: fn(id, deltas) {
          ref.set(written, Some(#(id, deltas)))
          Ok(Nil)
        },
      ),
    )
  #(result, ref.get(written))
}

pub fn removing_what_the_deck_holds_reaches_the_port_test() {
  assert remove("d1", 2)
    == #(Ok(Nil), Some(#("d1", [MemberDelta(key: key("1"), quantity: 2)])))
}

pub fn removing_more_than_the_deck_holds_is_rejected_not_clamped_test() {
  assert remove("d1", 3)
    == #(
      Error(ports.NotHeld(Underheld(key: key("1"), requested: 3, held: 2))),
      None,
    )
}

pub fn an_unknown_location_is_rejected_test() {
  assert remove("nope", 1) == #(Error(ports.UnknownLocation), None)
}
