import inventory_planning/domain/location_ref.{type LocationRef}

// --- Read model -----------------------------------------------------------

// One row of the placed ledger: how many copies of a key currently sit in a
// location. The client subtracts these from the projection to derive what is
// still to place, so a placement tick only refetches this cheap ledger rather
// than recomputing the whole projection.
pub type PlacedLedgerRow {
  PlacedLedgerRow(
    set_code: String,
    collector_number: String,
    finish: String,
    language: String,
    location: LocationRef,
    quantity: Int,
  )
}

// --- Driven port ----------------------------------------------------------

pub type GetPlacedLedgerPort =
  fn() -> Result(List(PlacedLedgerRow), String)
