import collection/driver/gleam/collection_api
import gleam/dict
import gleam/list
import gleam/result
import inventory_planning/application/commands/reconcile_placed_ledger/ports
import inventory_planning/domain/placed_ledger_reconciliation.{PlacedRow}
import inventory_planning/infrastructure/daos/placed_cards_dao
import shared/domain/copy_key

pub fn new() -> ports.ReconcilePlacedLedgerPorts {
  ports.ReconcilePlacedLedgerPorts(
    owned_quantities: owned_quantities_adapter(),
    list_placed: list_placed_adapter(),
    decrement_placed: decrement_placed_adapter(),
  )
}

fn owned_quantities_adapter() -> ports.OwnedQuantitiesPort {
  fn() {
    use copies <- result.map(collection_api.list_copies())
    dict.from_list(list.map(copies, fn(copy) { #(copy.key, copy.quantity) }))
  }
}

fn list_placed_adapter() -> ports.ListPlacedPort {
  fn() {
    use rows <- result.map(placed_cards_dao.list())
    list.filter_map(rows, fn(row) {
      case
        copy_key.new(
          set_code: row.set_code,
          collector_number: row.collector_number,
          finish: row.finish,
          language: row.language,
        )
      {
        Ok(key) ->
          Ok(PlacedRow(key:, location: row.location, quantity: row.quantity))
        // placed_cards rows are already canonical (parsed at the write
        // boundary), so this is unreachable in practice — skipping rather
        // than crashing keeps the read total, same precedent as
        // collection_api.to_owned_copies.
        Error(_) -> Error(Nil)
      }
    })
  }
}

fn decrement_placed_adapter() -> ports.DecrementPlacedPort {
  fn(rows) {
    placed_cards_dao.decrement(
      list.map(rows, fn(row) {
        let PlacedRow(key:, location:, quantity:) = row
        placed_cards_dao.PlacedCardRow(
          set_code: copy_key.set_code_string(key),
          collector_number: copy_key.collector_number_string(key),
          finish: copy_key.finish_string(key),
          language: copy_key.language_string(key),
          location:,
          quantity:,
        )
      }),
    )
  }
}
