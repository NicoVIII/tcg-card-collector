import inventory_planning/application/commands/add_to_managed_location/ports as add_to_managed_location_ports
import inventory_planning/application/commands/delete_rule/ports as delete_rule_ports
import inventory_planning/application/commands/mark_cards_placed/ports as mark_cards_placed_ports
import inventory_planning/application/commands/relocate_placed_cards/ports as relocate_placed_cards_ports
import inventory_planning/application/commands/reorder_rules/ports as reorder_rules_ports
import inventory_planning/application/commands/unmark_cards_placed/ports as unmark_cards_placed_ports
import inventory_planning/application/commands/update_bulk_spec/ports as update_bulk_spec_ports
import inventory_planning/application/commands/upsert_rule/ports as upsert_rule_ports
import inventory_planning/domain/managed_location
import inventory_planning/driver/error_presentation
import shared/domain/copy_key
import shared/driver/presented_error.{BadRequest, Internal, PresentedError}

pub fn upsert_rule_validation_errors_are_bad_requests_test() {
  assert error_presentation.upsert_rule(upsert_rule_ports.InvalidExpression)
    == PresentedError(BadRequest, "invalid inventory rule expression")
  assert error_presentation.upsert_rule(upsert_rule_ports.InvalidSelector)
    == PresentedError(BadRequest, "invalid inventory rule selector")
  assert error_presentation.upsert_rule(upsert_rule_ports.InvalidSortKeys)
    == PresentedError(BadRequest, "invalid inventory rule sort keys")
}

// The persistence reason is operator detail; clients get a fixed message.
pub fn persistence_failures_hide_the_reason_test() {
  assert error_presentation.upsert_rule(upsert_rule_ports.PersistenceFailed(
      "disk full",
    ))
    == PresentedError(Internal, "failed to save inventory rule")
  assert error_presentation.delete_rule(
      delete_rule_ports.DeleteInventoryRuleError("disk full"),
    )
    == PresentedError(Internal, "failed to delete inventory rule")
  assert error_presentation.update_bulk_spec(
      update_bulk_spec_ports.PersistenceFailed("disk full"),
    )
    == PresentedError(Internal, "failed to save bulk spec")
  assert error_presentation.mark_cards_placed(
      mark_cards_placed_ports.PersistenceFailed("disk full"),
    )
    == PresentedError(Internal, "failed to mark cards placed")
  assert error_presentation.unmark_cards_placed(
      unmark_cards_placed_ports.PersistenceFailed("disk full"),
    )
    == PresentedError(Internal, "failed to unmark cards placed")
  assert error_presentation.reorder_rules(reorder_rules_ports.PersistenceFailed(
      "disk full",
    ))
    == PresentedError(Internal, "failed to save rule order")
  assert error_presentation.relocate_placed_cards(
      relocate_placed_cards_ports.PersistenceFailed("disk full"),
    )
    == PresentedError(Internal, "failed to relocate placed cards")
}

pub fn reorder_rules_not_a_permutation_is_a_bad_request_test() {
  assert error_presentation.reorder_rules(reorder_rules_ports.NotAPermutation)
    == PresentedError(
      BadRequest,
      "rule order must list every existing rule exactly once",
    )
}

pub fn other_validation_errors_are_bad_requests_test() {
  assert error_presentation.update_bulk_spec(
      update_bulk_spec_ports.InvalidSortKeys,
    )
    == PresentedError(BadRequest, "invalid bulk sort keys")
  assert error_presentation.mark_cards_placed(
      mark_cards_placed_ports.InvalidPlacements,
    )
    == PresentedError(BadRequest, "invalid placements")
  assert error_presentation.unmark_cards_placed(
      unmark_cards_placed_ports.InvalidPlacements,
    )
    == PresentedError(BadRequest, "invalid placements")
  assert error_presentation.relocate_placed_cards(
      relocate_placed_cards_ports.InvalidRelocation,
    )
    == PresentedError(BadRequest, "invalid relocation")
}

// The client should have prevented an over-claim, so it's a 400 — but one
// that names the copy and the numbers, so a stale page can still act on it.
pub fn an_overclaim_names_the_copy_and_what_is_free_test() {
  let assert Ok(key) =
    copy_key.new(
      set_code: "lea",
      collector_number: "161",
      finish: "foil",
      language: "de",
    )

  assert error_presentation.add_to_managed_location(
      add_to_managed_location_ports.NotEnoughOwned(managed_location.Overclaim(
        key:,
        requested: 3,
        available: 1,
      )),
    )
    == PresentedError(
      BadRequest,
      "only 1 unclaimed cop(ies) of lea 161 (foil, de) left to add, 3 requested",
    )
}
