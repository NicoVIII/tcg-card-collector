import gleam/list
import inventory_planning/domain/placement

pub fn new_canonicalizes_the_key_test() {
  let assert Ok(built) =
    placement.new(
      set_code: "  LEA ",
      collector_number: " 161 ",
      location: "Bulk",
      quantity: 2,
    )

  assert placement.set_code_string(built) == "lea"
  assert placement.collector_number_string(built) == "161"
  assert placement.location(built) == "Bulk"
  assert placement.quantity(built) == 2
}

pub fn new_rejects_an_empty_set_code_test() {
  assert placement.new(
      set_code: "",
      collector_number: "1",
      location: "Bulk",
      quantity: 1,
    )
    == Error(placement.InvalidKey)
}

pub fn new_rejects_an_empty_location_test() {
  assert placement.new(
      set_code: "lea",
      collector_number: "1",
      location: "   ",
      quantity: 1,
    )
    == Error(placement.EmptyLocation)
}

pub fn new_rejects_a_non_positive_quantity_test() {
  assert placement.new(
      set_code: "lea",
      collector_number: "1",
      location: "Bulk",
      quantity: 0,
    )
    == Error(placement.NonPositiveQuantity)
}

pub fn merge_sums_duplicate_key_and_location_and_keeps_others_separate_test() {
  let assert Ok(a1) =
    placement.new(
      set_code: "lea",
      collector_number: "1",
      location: "Bulk",
      quantity: 2,
    )
  let assert Ok(a2) =
    placement.new(
      set_code: "lea",
      collector_number: "1",
      location: "Bulk",
      quantity: 3,
    )
  let assert Ok(b) =
    placement.new(
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
