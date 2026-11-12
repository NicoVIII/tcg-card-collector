import gleam/option.{type Option}
import inventory_planning/domain/location_audit.{type AuditRecord}
import inventory_planning/domain/location_ref.{type LocationRef}
import inventory_planning/domain/managed_location.{type ManagedLocation}
import shared/domain/copy_key.{type CopyKey}

pub type RuleWriteModel {
  RuleWriteModel(
    id: String,
    location_name: String,
    expression: String,
    position: Int,
    selector: String,
    sort_keys: String,
  )
}

pub type BulkSpecWriteModel {
  BulkSpecWriteModel(location_name: String, sort_keys: String)
}

pub type PlacedWriteModel {
  PlacedWriteModel(key: CopyKey, location: LocationRef, quantity: Int)
}

/// Replaces whichever of rules/bulk/managed/placed/audits are `Some`,
/// atomically together — a `None` part is left untouched (ADR 0019:
/// Portability's restore, one context, one transaction). Replacing the
/// managed locations also drops every placed-ledger row and audit recorded
/// at the old ones, since their ids no longer exist.
pub type ReplacePlanPort =
  fn(
    Option(List(RuleWriteModel)),
    Option(BulkSpecWriteModel),
    Option(List(ManagedLocation)),
    Option(List(PlacedWriteModel)),
    Option(List(AuditRecord)),
  ) -> Result(Nil, String)

pub type RestorePlanPorts {
  RestorePlanPorts(
    replace_plan: ReplacePlanPort,
    list_managed_locations: fn() -> Result(List(ManagedLocation), String),
  )
}

pub type RestorePlanError {
  InvalidRules
  InvalidBulkSpec
  InvalidManagedLocations
  InvalidPlaced
  InvalidAudits
  PersistenceFailed(reason: String)
}
