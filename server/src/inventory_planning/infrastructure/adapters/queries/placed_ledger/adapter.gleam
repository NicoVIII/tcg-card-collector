import gleam/list
import gleam/result
import inventory_planning/application/queries/placed_ledger/ports
import inventory_planning/domain/location_ref
import inventory_planning/infrastructure/daos/placed_cards_dao

pub fn new() -> ports.GetPlacedLedgerPort {
  fn() {
    use rows <- result.map(placed_cards_dao.list())
    list.filter_map(rows, fn(row) {
      // The CHECK on location_kind and the write-side parse keep this
      // unreachable in practice; skipping keeps the read total, same
      // precedent as the reconcile adapter's CopyKey parse.
      use location <- result.map(location_ref.new(
        kind: row.location_kind,
        key: row.location,
      ))
      ports.PlacedLedgerRow(
        set_code: row.set_code,
        collector_number: row.collector_number,
        finish: row.finish,
        language: row.language,
        location:,
        quantity: row.quantity,
      )
    })
  }
}
