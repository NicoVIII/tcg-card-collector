import gleam/list
import gleam/result
import inventory_planning/application/queries/placed_ledger/ports
import inventory_planning/infrastructure/daos/placed_cards_dao

pub fn new() -> ports.GetPlacedLedgerPort {
  fn() {
    use rows <- result.map(placed_cards_dao.list())
    list.map(rows, fn(row) {
      ports.PlacedLedgerRow(
        set_code: row.set_code,
        collector_number: row.collector_number,
        finish: row.finish,
        language: row.language,
        location: row.location,
        quantity: row.quantity,
      )
    })
  }
}
