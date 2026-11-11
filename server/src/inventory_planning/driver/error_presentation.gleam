import gleam/int
import inventory_planning/application/commands/add_to_managed_location/ports as add_to_managed_location_ports
import inventory_planning/application/commands/complete_location_audit/ports as complete_location_audit_ports
import inventory_planning/application/commands/create_managed_location/ports as create_managed_location_ports
import inventory_planning/application/commands/delete_managed_location/ports as delete_managed_location_ports
import inventory_planning/application/commands/delete_rule/ports as delete_rule_ports
import inventory_planning/application/commands/mark_cards_placed/ports as mark_cards_placed_ports
import inventory_planning/application/commands/relocate_placed_cards/ports as relocate_placed_cards_ports
import inventory_planning/application/commands/remove_from_managed_location/ports as remove_from_managed_location_ports
import inventory_planning/application/commands/rename_managed_location/ports as rename_managed_location_ports
import inventory_planning/application/commands/reorder_rules/ports as reorder_rules_ports
import inventory_planning/application/commands/unmark_cards_placed/ports as unmark_cards_placed_ports
import inventory_planning/application/commands/update_bulk_spec/ports as update_bulk_spec_ports
import inventory_planning/application/commands/upsert_rule/ports as upsert_rule_ports
import inventory_planning/domain/location_audit
import inventory_planning/domain/managed_location
import shared/domain/copy_key.{type CopyKey}
import shared/driver/presented_error.{
  type PresentedError, BadRequest, Internal, PresentedError,
}

pub fn upsert_rule(
  error: upsert_rule_ports.UpsertInventoryRuleError,
) -> PresentedError {
  case error {
    upsert_rule_ports.InvalidLocationName ->
      PresentedError(BadRequest, "inventory rule location name is blank")
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
    update_bulk_spec_ports.InvalidLocationName ->
      PresentedError(BadRequest, "bulk location name is blank")
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

pub fn relocate_placed_cards(
  error: relocate_placed_cards_ports.RelocatePlacedCardsError,
) -> PresentedError {
  case error {
    relocate_placed_cards_ports.InvalidRelocation ->
      PresentedError(BadRequest, "invalid relocation")
    relocate_placed_cards_ports.PersistenceFailed(_) ->
      PresentedError(Internal, "failed to relocate placed cards")
  }
}

pub fn create_managed_location(
  error: create_managed_location_ports.CreateManagedLocationError,
) -> PresentedError {
  case error {
    create_managed_location_ports.InvalidId ->
      PresentedError(BadRequest, "a managed location needs an id")
    create_managed_location_ports.InvalidName ->
      PresentedError(BadRequest, "enter a name for the deck")
    create_managed_location_ports.InvalidKind ->
      PresentedError(BadRequest, "unknown managed location kind")
    create_managed_location_ports.DuplicateId ->
      PresentedError(
        BadRequest,
        "a managed location with this id already exists",
      )
    create_managed_location_ports.DuplicateName ->
      PresentedError(BadRequest, "a deck with this name already exists")
    create_managed_location_ports.PersistenceFailed(_) ->
      PresentedError(Internal, "failed to create deck")
  }
}

pub fn rename_managed_location(
  error: rename_managed_location_ports.RenameManagedLocationError,
) -> PresentedError {
  case error {
    rename_managed_location_ports.InvalidName ->
      PresentedError(BadRequest, "enter a name for the deck")
    rename_managed_location_ports.UnknownLocation ->
      PresentedError(BadRequest, "this deck no longer exists")
    rename_managed_location_ports.DuplicateName ->
      PresentedError(BadRequest, "a deck with this name already exists")
    rename_managed_location_ports.PersistenceFailed(_) ->
      PresentedError(Internal, "failed to rename deck")
  }
}

pub fn delete_managed_location(
  error: delete_managed_location_ports.DeleteManagedLocationError,
) -> PresentedError {
  case error {
    delete_managed_location_ports.UnknownLocation ->
      PresentedError(BadRequest, "this deck no longer exists")
    delete_managed_location_ports.PersistenceFailed(_) ->
      PresentedError(Internal, "failed to delete deck")
  }
}

pub fn add_to_managed_location(
  error: add_to_managed_location_ports.AddToManagedLocationError,
) -> PresentedError {
  case error {
    add_to_managed_location_ports.UnknownLocation ->
      PresentedError(BadRequest, "this deck no longer exists")
    add_to_managed_location_ports.InvalidCopies ->
      PresentedError(BadRequest, "invalid cards to add")
    add_to_managed_location_ports.NotEnoughOwned(overclaim) ->
      PresentedError(BadRequest, overclaim_message(overclaim))
    add_to_managed_location_ports.PersistenceFailed(_) ->
      PresentedError(Internal, "failed to add cards to deck")
  }
}

pub fn remove_from_managed_location(
  error: remove_from_managed_location_ports.RemoveFromManagedLocationError,
) -> PresentedError {
  case error {
    remove_from_managed_location_ports.UnknownLocation ->
      PresentedError(BadRequest, "this deck no longer exists")
    remove_from_managed_location_ports.InvalidCopies ->
      PresentedError(BadRequest, "invalid cards to remove")
    remove_from_managed_location_ports.NotHeld(underheld) ->
      PresentedError(BadRequest, underheld_message(underheld))
    remove_from_managed_location_ports.PersistenceFailed(_) ->
      PresentedError(Internal, "failed to remove cards from deck")
  }
}

fn copy_label(key: CopyKey) -> String {
  copy_key.set_code_string(key)
  <> " "
  <> copy_key.collector_number_string(key)
  <> " ("
  <> copy_key.finish_string(key)
  <> ", "
  <> copy_key.language_string(key)
  <> ")"
}

fn overclaim_message(overclaim: managed_location.Overclaim) -> String {
  "only "
  <> int.to_string(overclaim.available)
  <> " unclaimed cop(ies) of "
  <> copy_label(overclaim.key)
  <> " left to add, "
  <> int.to_string(overclaim.requested)
  <> " requested"
}

fn underheld_message(underheld: managed_location.Underheld) -> String {
  "the deck holds "
  <> int.to_string(underheld.held)
  <> " cop(ies) of "
  <> copy_label(underheld.key)
  <> ", "
  <> int.to_string(underheld.requested)
  <> " requested"
}

fn audit_rejection_message(rejection: location_audit.Rejection) -> String {
  case rejection {
    location_audit.NotRecordedHere(key:, requested:, recorded:) ->
      "the ledger records "
      <> int.to_string(recorded)
      <> " cop(ies) of "
      <> copy_label(key)
      <> " at this location, "
      <> int.to_string(requested)
      <> " reported missing"
    location_audit.NotRecordedAtSource(key:, requested:, recorded:, ..) ->
      "the ledger records "
      <> int.to_string(recorded)
      <> " cop(ies) of "
      <> copy_label(key)
      <> " at the location named as its source, "
      <> int.to_string(requested)
      <> " to move"
    location_audit.ExceedsOwned(key:, requested:, available:) ->
      "only "
      <> int.to_string(available)
      <> " owned cop(ies) of "
      <> copy_label(key)
      <> " are not placed anywhere, "
      <> int.to_string(requested)
      <> " found; name the location they came from"
  }
}

pub fn complete_location_audit(
  error: complete_location_audit_ports.CompleteLocationAuditError,
) -> PresentedError {
  case error {
    complete_location_audit_ports.UnknownLocation ->
      PresentedError(BadRequest, "this deck no longer exists")
    complete_location_audit_ports.InvalidAudit ->
      PresentedError(BadRequest, "invalid audit findings")
    complete_location_audit_ports.Rejected(rejection) ->
      PresentedError(BadRequest, audit_rejection_message(rejection))
    complete_location_audit_ports.PersistenceFailed(_) ->
      PresentedError(Internal, "failed to complete the audit")
  }
}
