import gleam/list
import inventory_planning/domain/placement

fn new_nonfoil_en(
  set_code set_code: String,
  collector_number collector_number: String,
  location location: String,
  quantity quantity: Int,
) -> Result(placement.Placement, placement.PlacementError) {
  placement.new(
    set_code:,
    collector_number:,
    finish: "nonfoil",
    language: "en",
    location:,
    quantity:,
  )
}

pub fn new_canonicalizes_the_key_test() {
  let assert Ok(built) =
    placement.new(
      set_code: "  LEA ",
      collector_number: " 161 ",
      finish: " FOIL ",
      language: " DE ",
      location: "Bulk",
      quantity: 2,
    )

  assert placement.set_code_string(built) == "lea"
  assert placement.collector_number_string(built) == "161"
  assert placement.finish_string(built) == "foil"
  assert placement.language_string(built) == "de"
  assert placement.location(built) == "Bulk"
  assert placement.quantity(built) == 2
}

pub fn new_rejects_an_empty_set_code_test() {
  assert new_nonfoil_en(
      set_code: "",
      collector_number: "1",
      location: "Bulk",
      quantity: 1,
    )
    == Error(placement.InvalidKey)
}

pub fn new_rejects_an_unknown_finish_test() {
  assert placement.new(
      set_code: "lea",
      collector_number: "1",
      finish: "shiny",
      language: "en",
      location: "Bulk",
      quantity: 1,
    )
    == Error(placement.InvalidKey)
}

pub fn new_rejects_an_unknown_language_test() {
  assert placement.new(
      set_code: "lea",
      collector_number: "1",
      finish: "nonfoil",
      language: "klingon",
      location: "Bulk",
      quantity: 1,
    )
    == Error(placement.InvalidKey)
}

pub fn new_rejects_an_empty_location_test() {
  assert new_nonfoil_en(
      set_code: "lea",
      collector_number: "1",
      location: "   ",
      quantity: 1,
    )
    == Error(placement.EmptyLocation)
}

pub fn new_rejects_a_non_positive_quantity_test() {
  assert new_nonfoil_en(
      set_code: "lea",
      collector_number: "1",
      location: "Bulk",
      quantity: 0,
    )
    == Error(placement.NonPositiveQuantity)
}

pub fn merge_sums_duplicate_key_and_location_and_keeps_others_separate_test() {
  let assert Ok(a1) =
    new_nonfoil_en(
      set_code: "lea",
      collector_number: "1",
      location: "Bulk",
      quantity: 2,
    )
  let assert Ok(a2) =
    new_nonfoil_en(
      set_code: "lea",
      collector_number: "1",
      location: "Bulk",
      quantity: 3,
    )
  let assert Ok(b) =
    new_nonfoil_en(
      set_code: "lea",
      collector_number: "1",
      location: "Binder",
      quantity: 1,
    )

  let merged = placement.merge([a1, b, a2])

  let summary =
    list.map(merged, fn(p) { #(placement.location(p), placement.quantity(p)) })

  // Stable (key, location) order: Binder before Bulk.
  assert summary == [#("Binder", 1), #("Bulk", 5)]
}

// Same printing and location, different finish: distinct placements, not
// merged together — a location can hold several kinds of copy of one printing.
pub fn merge_keeps_different_finish_as_separate_placements_test() {
  let assert Ok(nonfoil) =
    new_nonfoil_en(
      set_code: "lea",
      collector_number: "1",
      location: "Binder",
      quantity: 2,
    )
  let assert Ok(foil) =
    placement.new(
      set_code: "lea",
      collector_number: "1",
      finish: "foil",
      language: "en",
      location: "Binder",
      quantity: 1,
    )

  let merged = placement.merge([nonfoil, foil])

  assert list.map(merged, fn(p) {
      #(placement.finish_string(p), placement.quantity(p))
    })
    == [#("foil", 1), #("nonfoil", 2)]
}

pub fn merge_orders_by_set_code_then_collector_number_then_location_test() {
  let place = fn(set_code, collector_number, location) {
    let assert Ok(p) =
      new_nonfoil_en(set_code:, collector_number:, location:, quantity: 1)
    p
  }

  let merged =
    placement.merge([
      place("m11", "1", "A"),
      place("lea", "2", "A"),
      place("lea", "1", "B"),
      place("lea", "1", "A"),
    ])

  assert list.map(merged, fn(p) {
      #(
        placement.set_code_string(p),
        placement.collector_number_string(p),
        placement.location(p),
      )
    })
    == [
      #("lea", "1", "A"),
      #("lea", "1", "B"),
      #("lea", "2", "A"),
      #("m11", "1", "A"),
    ]
}
