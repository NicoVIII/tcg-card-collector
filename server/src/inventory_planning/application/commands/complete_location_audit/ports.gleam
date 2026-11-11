import gleam/dict.{type Dict}
import gleam/time/timestamp.{type Timestamp}
import inventory_planning/domain/location_audit.{
  type AuditRecord, type LedgerChanges, type Rejection,
}
import inventory_planning/domain/placed_ledger_reconciliation.{type PlacedRow}
import shared/domain/copy_key.{type CopyKey}

pub type CompleteLocationAuditPorts {
  CompleteLocationAuditPorts(
    list_placed: fn() -> Result(List(PlacedRow), String),
    owned_quantities: fn() -> Result(Dict(CopyKey, Int), String),
    managed_location_ids: fn() -> Result(List(String), String),
    now: fn() -> Timestamp,
    /// Writes the ledger changes and the history record in one transaction.
    apply: fn(LedgerChanges, AuditRecord) -> Result(Nil, String),
  )
}

pub type CompleteLocationAuditError {
  UnknownLocation
  InvalidAudit
  Rejected(Rejection)
  PersistenceFailed(reason: String)
}
