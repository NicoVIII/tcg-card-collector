import gleam/dict.{type Dict}
import inventory_planning/domain/placed_ledger_reconciliation.{type PlacedRow}
import shared/domain/copy_key.{type CopyKey}

pub type OwnedQuantitiesPort =
  fn() -> Result(Dict(CopyKey, Int), String)

pub type ListPlacedPort =
  fn() -> Result(List(PlacedRow), String)

pub type DecrementPlacedPort =
  fn(List(PlacedRow)) -> Result(Nil, String)

pub type ReconcilePlacedLedgerPorts {
  ReconcilePlacedLedgerPorts(
    owned_quantities: OwnedQuantitiesPort,
    list_placed: ListPlacedPort,
    decrement_placed: DecrementPlacedPort,
  )
}

pub type ReconcilePlacedLedgerError {
  PersistenceFailed(reason: String)
}
