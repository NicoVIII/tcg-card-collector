import inventory_planning/application/commands/delete_rule/ports as delete_rule_ports
import inventory_planning/application/commands/mark_cards_placed/ports as mark_cards_placed_ports
import inventory_planning/application/commands/reorder_rules/ports as reorder_rules_ports
import inventory_planning/application/commands/unmark_cards_placed/ports as unmark_cards_placed_ports
import inventory_planning/application/commands/update_bulk_spec/ports as update_bulk_spec_ports
import inventory_planning/application/commands/upsert_rule/ports as upsert_rule_ports
import shared/driver/presented_error.{
  type PresentedError, BadRequest, Internal, PresentedError,
}

pub fn upsert_rule(
  error: upsert_rule_ports.UpsertInventoryRuleError,
) -> PresentedError {
  case error {
    upsert_rule_ports.InvalidExpression ->
      PresentedError(BadRequest, "invalid inventory rule expression")
    upsert_rule_ports.InvalidSelector ->
      PresentedError(BadRequest, "invalid inventory rule selector")
    upsert_rule_ports.InvalidSortKeys ->
      PresentedError(BadRequest, "invalid inventory rule sort keys")
    upsert_rule_ports.PersistenceFailed(_) ->
      PresentedError(Internal, "failed to save inventory rule")
  }
}

pub fn delete_rule(
  _error: delete_rule_ports.DeleteInventoryRuleError,
) -> PresentedError {
  PresentedError(Internal, "failed to delete inventory rule")
}

pub fn reorder_rules(
  error: reorder_rules_ports.ReorderInventoryRulesError,
) -> PresentedError {
  case error {
    reorder_rules_ports.NotAPermutation ->
      PresentedError(
        BadRequest,
        "rule order must list every existing rule exactly once",
      )
    reorder_rules_ports.PersistenceFailed(_) ->
      PresentedError(Internal, "failed to save rule order")
  }
}

pub fn update_bulk_spec(
  error: update_bulk_spec_ports.UpdateBulkSpecError,
) -> PresentedError {
  case error {
    update_bulk_spec_ports.InvalidSortKeys ->
      PresentedError(BadRequest, "invalid bulk sort keys")
    update_bulk_spec_ports.PersistenceFailed(_) ->
      PresentedError(Internal, "failed to save bulk spec")
  }
}

pub fn mark_cards_placed(
  error: mark_cards_placed_ports.MarkCardsPlacedError,
) -> PresentedError {
  case error {
    mark_cards_placed_ports.InvalidPlacements ->
      PresentedError(BadRequest, "invalid placements")
    mark_cards_placed_ports.PersistenceFailed(_) ->
      PresentedError(Internal, "failed to mark cards placed")
  }
}

pub fn unmark_cards_placed(
  error: unmark_cards_placed_ports.UnmarkCardsPlacedError,
) -> PresentedError {
  case error {
    unmark_cards_placed_ports.InvalidPlacements ->
      PresentedError(BadRequest, "invalid placements")
    unmark_cards_placed_ports.PersistenceFailed(_) ->
      PresentedError(Internal, "failed to unmark cards placed")
  }
}
