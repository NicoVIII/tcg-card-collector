import gleam/dict
import gleam/option.{type Option, None, Some}
import inventory_planning/application/commands/add_to_managed_location/handler
import inventory_planning/application/commands/add_to_managed_location/ports
import inventory_planning/domain/managed_location.{
  type MemberDelta, Deck, ManagedLocation, MemberDelta, Overclaim,
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

fn raw(collector_number: String, quantity: Int) -> handler.RawCopy {
  handler.RawCopy(
    set_code: "LEA",
    collector_number:,
    finish: "nonfoil",
    language: "en",
    quantity:,
  )
}

// Burn already holds two of lea 1; three are owned.
fn build_ports(
  written: ref.Ref(Option(#(String, List(MemberDelta)))),
) -> ports.AddToManagedLocationPorts {
  ports.AddToManagedLocationPorts(
    list_locations: fn() {
      Ok([
        ManagedLocation("d1", "Burn", Deck, dict.from_list([#(key("1"), 2)])),
        ManagedLocation("d2", "Aggro", Deck, dict.new()),
      ])
    },
    owned_quantities: fn() { Ok(dict.from_list([#(key("1"), 3)])) },
    increment_members: fn(id, deltas) {
      ref.set(written, Some(#(id, deltas)))
      Ok(Nil)
    },
  )
}

fn add(id: String, copies: List(handler.RawCopy)) {
  let written = ref.new(None)
  let result =
    handler.execute(
      handler.AddToManagedLocationCommand(id:, copies:),
      build_ports(written),
    )
  #(result, ref.get(written))
}

pub fn a_free_copy_is_added_with_its_key_canonicalized_test() {
  assert add("d2", [raw("1", 1)])
    == #(Ok(Nil), Some(#("d2", [MemberDelta(key: key("1"), quantity: 1)])))
}

// The batch is checked as a whole: two half-requests for the same key are
// one request for two, and only one copy is free.
pub fn claiming_beyond_what_another_deck_leaves_free_is_rejected_test() {
  assert add("d2", [raw("1", 1), raw("1", 1)])
    == #(
      Error(
        ports.NotEnoughOwned(Overclaim(
          key: key("1"),
          requested: 2,
          available: 1,
        )),
      ),
      None,
    )
}

pub fn an_unknown_location_is_rejected_test() {
  assert add("nope", [raw("1", 1)]) == #(Error(ports.UnknownLocation), None)
}

pub fn an_empty_or_invalid_batch_is_rejected_test() {
  assert add("d2", []) == #(Error(ports.InvalidCopies), None)
  assert add("d2", [raw("1", 0)]) == #(Error(ports.InvalidCopies), None)
}
