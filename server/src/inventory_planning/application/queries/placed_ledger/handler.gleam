import inventory_planning/application/queries/placed_ledger/ports

pub type GetPlacedLedgerQuery {
  GetPlacedLedgerQuery
}

// A thin read: the ledger is returned as-is for the client to fold against the
// projection. Aggregation lives at the point of use, not here.
pub fn execute(
  _query: GetPlacedLedgerQuery,
  port: ports.GetPlacedLedgerPort,
) -> Result(List(ports.PlacedLedgerRow), String) {
  port()
}
