import inventory_planning/application/queries/placed_ledger/handler
import inventory_planning/application/queries/placed_ledger/ports

// The handler is a thin read: it returns whatever the ledger port yields, for
// the client to fold against the projection. The acceptance test pins that the
// rows pass through untouched, and that a read error propagates rather than
// collapsing to an empty ledger.
pub fn returns_the_ledger_rows_test() {
  let rows = [
    ports.PlacedLedgerRow(
      set_code: "m11",
      collector_number: "146",
      location: "Bulk",
      quantity: 2,
    ),
  ]

  assert handler.execute(handler.GetPlacedLedgerQuery, fn() { Ok(rows) })
    == Ok(rows)
}

pub fn propagates_a_read_error_test() {
  assert handler.execute(handler.GetPlacedLedgerQuery, fn() {
      Error("db unavailable")
    })
    == Error("db unavailable")
}
