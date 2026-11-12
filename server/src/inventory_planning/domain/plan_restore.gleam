import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/time/timestamp.{type Timestamp}
import inventory_planning/domain/location_audit.{type AuditRecord, AuditRecord}
import inventory_planning/domain/location_ref
import inventory_planning/domain/managed_location.{type ManagedLocation}
import inventory_planning/domain/placed_ledger_reconciliation.{
  type PlacedRow, PlacedRow,
}
import inventory_planning/domain/placement

/// `location_kind` is "cascade" or "managed". For a cascade location,
/// `location` is its name; for a managed one it is the managed location's
/// *name* too, not its id — a restore assigns fresh ids, so the name is the
/// only identity the caller can hold. It resolves against the managed
/// locations being restored, or the existing ones when none are.
pub type RawPlaced {
  RawPlaced(
    set_code: String,
    collector_number: String,
    finish: String,
    language: String,
    location_kind: String,
    location: String,
    quantity: Int,
  )
}

pub type RawMember {
  RawMember(
    set_code: String,
    collector_number: String,
    finish: String,
    language: String,
    quantity: Int,
  )
}

/// No id: a restore assigns `imported-managed-<position>` itself, so the
/// position is the only identity it carries.
pub type RawManagedLocation {
  RawManagedLocation(name: String, kind: String, members: List(RawMember))
}

/// One completed audit, its location named the way `RawPlaced` names one.
pub type RawAudit {
  RawAudit(location_kind: String, location: String, completed_at: Timestamp)
}

pub type PlanRestoreError {
  InvalidManagedLocations
  InvalidPlaced
  InvalidAudits
}

fn validate_managed(
  raw: Option(List(RawManagedLocation)),
) -> Result(Option(List(ManagedLocation)), PlanRestoreError) {
  case raw {
    None -> Ok(None)
    Some(rows) -> {
      use locations <- result.try(
        rows
        |> list.index_map(to_managed_location)
        |> result.all
        |> result.replace_error(InvalidManagedLocations),
      )
      let names = list.map(locations, fn(location) { location.name })
      case list.length(list.unique(names)) == list.length(names) {
        True -> Ok(Some(locations))
        False -> Error(InvalidManagedLocations)
      }
    }
  }
}

fn to_managed_location(
  row: RawManagedLocation,
  position: Int,
) -> Result(ManagedLocation, Nil) {
  use name <- result.try(managed_location.parse_name(row.name))
  use kind <- result.try(managed_location.kind_from_string(row.kind))
  use deltas <- result.try(list.try_map(row.members, to_member_delta))
  Ok(managed_location.ManagedLocation(
    id: "imported-managed-" <> int.to_string(position),
    name:,
    kind:,
    members: managed_location.merge_deltas(deltas)
      |> list.map(fn(delta) { #(delta.key, delta.quantity) })
      |> dict.from_list,
  ))
}

fn to_member_delta(
  member: RawMember,
) -> Result(managed_location.MemberDelta, Nil) {
  managed_location.delta_from_input(
    set_code: member.set_code,
    collector_number: member.collector_number,
    finish: member.finish,
    language: member.language,
    quantity: member.quantity,
  )
}

// A managed placed entry names its location; resolve against the set being
// restored when there is one (it replaces the old one wholesale), else the
// existing locations.
fn managed_ids_by_name(
  locations: List(ManagedLocation),
) -> Dict(String, String) {
  locations
  |> list.map(fn(location) { #(location.name, location.id) })
  |> dict.from_list
}

fn to_placed_row(p: placement.Placement) -> PlacedRow {
  PlacedRow(
    key: placement.key(p),
    location: placement.location(p),
    quantity: placement.quantity(p),
  )
}

fn validate_placed(
  raw: Option(List(RawPlaced)),
  managed_ids: Dict(String, String),
) -> Result(Option(List(PlacedRow)), PlanRestoreError) {
  case raw {
    None -> Ok(None)
    Some(rows) ->
      rows
      |> list.try_map(to_placement(_, managed_ids))
      |> result.replace_error(InvalidPlaced)
      |> result.map(fn(placements) {
        Some(list.map(placement.merge(placements), to_placed_row))
      })
  }
}

fn to_placement(
  row: RawPlaced,
  managed_ids: Dict(String, String),
) -> Result(placement.Placement, placement.PlacementError) {
  use location <- result.try(case row.location_kind {
    "managed" ->
      dict.get(managed_ids, row.location)
      |> result.replace_error(placement.InvalidLocation)
    _ -> Ok(row.location)
  })
  placement.new(
    set_code: row.set_code,
    collector_number: row.collector_number,
    finish: row.finish,
    language: row.language,
    location_kind: row.location_kind,
    location:,
    quantity: row.quantity,
  )
}

/// The managed locations and placed-ledger rows a restore writes, every name
/// resolved to the id the restore assigns (`imported-managed-<position>`) or,
/// when the managed section is absent, to an existing location's. A `None`
/// section is absent from the restore and left untouched. Shared by
/// RestorePlan and PredictRestorePrune, so the prediction resolves names to
/// the same ids the write does.
pub fn restored_ledger(
  managed: Option(List(RawManagedLocation)),
  placed: Option(List(RawPlaced)),
  existing_managed: List(ManagedLocation),
) -> Result(
  #(Option(List(ManagedLocation)), Option(List(PlacedRow))),
  PlanRestoreError,
) {
  use restored <- result.try(validate_managed(managed))
  let ids = managed_ids_by_name(option.unwrap(restored, existing_managed))
  use rows <- result.map(validate_placed(placed, ids))
  #(restored, rows)
}

/// Whether a restore empties the audit history: it carries no history of its
/// own but replaces the ledger, and every audit attested a ledger that is
/// then gone (#183).
pub fn clears_audit_history(
  restores_audits restores_audits: Bool,
  replaces_ledger replaces_ledger: Bool,
) -> Bool {
  !restores_audits && replaces_ledger
}

fn to_audit_record(
  raw: RawAudit,
  managed_ids: Dict(String, String),
) -> Result(AuditRecord, Nil) {
  use key <- result.try(case raw.location_kind {
    "managed" -> dict.get(managed_ids, raw.location)
    _ -> Ok(raw.location)
  })
  use location <- result.map(location_ref.new(raw.location_kind, key))
  AuditRecord(location:, completed_at: raw.completed_at)
}

/// The audit history a restore writes, names resolved against `managed` —
/// the managed locations the restore leaves behind. `None` leaves the
/// history untouched; `Some([])` empties it (`clears_audit_history`). A
/// repeated audit collapses to one, as the history holds each completion
/// once.
pub fn restored_audits(
  audits: Option(List(RawAudit)),
  replaces_ledger: Bool,
  managed: List(ManagedLocation),
) -> Result(Option(List(AuditRecord)), PlanRestoreError) {
  case audits {
    Some(rows) ->
      rows
      |> list.try_map(to_audit_record(_, managed_ids_by_name(managed)))
      |> result.replace_error(InvalidAudits)
      |> result.map(fn(records) { Some(list.unique(records)) })
    None ->
      case clears_audit_history(restores_audits: False, replaces_ledger:) {
        True -> Ok(Some([]))
        False -> Ok(None)
      }
  }
}
