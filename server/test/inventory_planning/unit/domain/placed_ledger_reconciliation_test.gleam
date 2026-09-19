import gleam/dict
import inventory_planning/domain/placed_ledger_reconciliation.{PlacedRow}
import shared/domain/copy_key.{type CopyKey}

fn key(set_code: String, collector_number: String) -> CopyKey {
  let assert Ok(key) =
    copy_key.new(
      set_code:,
      collector_number:,
      finish: "nonfoil",
      language: "en",
    )
  key
}

pub fn a_key_within_bounds_is_left_alone_test() {
  let lea1 = key("lea", "1")
  let owned = dict.from_list([#(lea1, 3)])
  let placed = [PlacedRow(key: lea1, location: "Bulk", quantity: 3)]

  assert placed_ledger_reconciliation.excess_to_prune(owned, placed) == []
}

pub fn excess_prunes_a_single_location_partially_test() {
  let lea1 = key("lea", "1")
  let owned = dict.from_list([#(lea1, 1)])
  let placed = [PlacedRow(key: lea1, location: "Bulk", quantity: 3)]

  assert placed_ledger_reconciliation.excess_to_prune(owned, placed)
    == [PlacedRow(key: lea1, location: "Bulk", quantity: 2)]
}

pub fn a_key_fully_absent_from_owned_is_pruned_entirely_test() {
  let lea1 = key("lea", "1")
  let owned = dict.new()
  let placed = [PlacedRow(key: lea1, location: "Bulk", quantity: 3)]

  assert placed_ledger_reconciliation.excess_to_prune(owned, placed)
    == [PlacedRow(key: lea1, location: "Bulk", quantity: 3)]
}

// No location to blame for the excess, so the tie-break is alphabetical
// (ADR 0011): "Binder" loses copies before "Box" does.
pub fn excess_prunes_locations_in_alphabetical_order_test() {
  let lea1 = key("lea", "1")
  let owned = dict.from_list([#(lea1, 1)])
  let placed = [
    PlacedRow(key: lea1, location: "Box", quantity: 2),
    PlacedRow(key: lea1, location: "Binder", quantity: 2),
  ]

  assert placed_ledger_reconciliation.excess_to_prune(owned, placed)
    == [
      PlacedRow(key: lea1, location: "Binder", quantity: 2),
      PlacedRow(key: lea1, location: "Box", quantity: 1),
    ]
}

pub fn only_keys_with_excess_appear_in_the_result_test() {
  let lea1 = key("lea", "1")
  let lea2 = key("lea", "2")
  let owned = dict.from_list([#(lea1, 3), #(lea2, 0)])
  let placed = [
    PlacedRow(key: lea1, location: "Bulk", quantity: 3),
    PlacedRow(key: lea2, location: "Bulk", quantity: 1),
  ]

  assert placed_ledger_reconciliation.excess_to_prune(owned, placed)
    == [PlacedRow(key: lea2, location: "Bulk", quantity: 1)]
}

pub fn no_placed_rows_prunes_nothing_test() {
  let owned = dict.from_list([#(key("lea", "1"), 3)])

  assert placed_ledger_reconciliation.excess_to_prune(owned, []) == []
}
