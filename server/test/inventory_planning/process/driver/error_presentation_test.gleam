import inventory_planning/application/commands/delete_rule/ports as delete_rule_ports
import inventory_planning/application/commands/mark_cards_placed/ports as mark_cards_placed_ports
import inventory_planning/application/commands/unmark_cards_placed/ports as unmark_cards_placed_ports
import inventory_planning/application/commands/update_bulk_spec/ports as update_bulk_spec_ports
import inventory_planning/application/commands/update_preferences/ports as update_preferences_ports
import inventory_planning/application/commands/upsert_rule/ports as upsert_rule_ports
import inventory_planning/driver/error_presentation
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
  assert error_presentation.update_preferences(
      update_preferences_ports.PersistenceFailed("disk full"),
    )
    == PresentedError(Internal, "failed to save settings")
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
  assert error_presentation.update_preferences(
      update_preferences_ports.InvalidPreferences,
    )
    == PresentedError(BadRequest, "invalid settings")
}
