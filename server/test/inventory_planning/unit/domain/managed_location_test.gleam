import gleam/dict
import inventory_planning/domain/managed_location.{
  Deck, ManagedLocation, MemberDelta, Overclaim, Underheld,
}
import shared/domain/copy_key.{type CopyKey}

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

fn deck(
  id: String,
  name: String,
  members: List(#(CopyKey, Int)),
) -> managed_location.ManagedLocation {
  ManagedLocation(id:, name:, kind: Deck, members: dict.from_list(members))
}

pub fn parse_name_trims_and_rejects_blank_test() {
  assert managed_location.parse_name("  Mono-Red ") == Ok("Mono-Red")
  assert managed_location.parse_name("   ") == Error(Nil)
}

pub fn name_taken_ignores_the_location_being_renamed_test() {
  let locations = [deck("d1", "Mono-Red", []), deck("d2", "Burn", [])]

  assert managed_location.name_taken(locations, "Burn", except_id: "d1")
  assert !managed_location.name_taken(locations, "Burn", except_id: "d2")
  assert !managed_location.name_taken(locations, "Elves", except_id: "")
}

pub fn delta_from_input_canonicalizes_and_requires_a_positive_quantity_test() {
  assert managed_location.delta_from_input(
      set_code: " LEA ",
      collector_number: "1",
      finish: "nonfoil",
      language: "en",
      quantity: 2,
    )
    == Ok(MemberDelta(key: key("1"), quantity: 2))
  assert managed_location.delta_from_input(
      set_code: "lea",
      collector_number: "1",
      finish: "nonfoil",
      language: "en",
      quantity: 0,
    )
    == Error(Nil)
}

// Two half-requests for the same key must be checked as one whole request.
pub fn merge_deltas_sums_a_repeated_key_test() {
  assert managed_location.merge_deltas([
      MemberDelta(key: key("2"), quantity: 1),
      MemberDelta(key: key("1"), quantity: 1),
      MemberDelta(key: key("1"), quantity: 2),
    ])
    == [
      MemberDelta(key: key("1"), quantity: 3),
      MemberDelta(key: key("2"), quantity: 1),
    ]
}

// Free copies are owned minus what every managed location already claims,
// so a second deck can't claim a copy the first already holds.
pub fn check_addition_counts_claims_from_every_deck_test() {
  let owned = dict.from_list([#(key("1"), 3)])
  let claimed =
    managed_location.claimed_totals([
      deck("d1", "Burn", [#(key("1"), 2)]),
      deck("d2", "Aggro", []),
    ])

  assert managed_location.check_addition(
      [MemberDelta(key: key("1"), quantity: 1)],
      owned:,
      claimed:,
    )
    == Ok(Nil)
  assert managed_location.check_addition(
      [MemberDelta(key: key("1"), quantity: 2)],
      owned:,
      claimed:,
    )
    == Error(Overclaim(key: key("1"), requested: 2, available: 1))
}

// A shortfall (claims above what's owned) frees nothing up.
pub fn check_addition_reports_zero_free_under_a_shortfall_test() {
  let owned = dict.from_list([#(key("1"), 1)])
  let claimed = dict.from_list([#(key("1"), 3)])

  assert managed_location.check_addition(
      [MemberDelta(key: key("1"), quantity: 1)],
      owned:,
      claimed:,
    )
    == Error(Overclaim(key: key("1"), requested: 1, available: 0))
}

pub fn check_removal_rejects_more_than_the_deck_holds_test() {
  let location = deck("d1", "Burn", [#(key("1"), 2)])

  assert managed_location.check_removal(location, [
      MemberDelta(key: key("1"), quantity: 2),
    ])
    == Ok(Nil)
  assert managed_location.check_removal(location, [
      MemberDelta(key: key("2"), quantity: 1),
    ])
    == Error(Underheld(key: key("2"), requested: 1, held: 0))
}
