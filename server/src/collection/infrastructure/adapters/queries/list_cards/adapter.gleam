import collection/application/queries/list_cards/ports
import collection/infrastructure/daos/collection_dao
import gleam/list

pub fn new() -> ports.ListCollectionCardsPort {
  ports.ListCollectionCardsPort(list_cards: list_cards_adapter())
}

fn list_cards_adapter() -> fn() -> List(ports.CollectionCardReadModel) {
  fn() {
    collection_dao.snapshot_rows()
    |> list.map(fn(row) {
      let #(set_code, collector_number, quantity) = row
      ports.CollectionCardReadModel(
        set_code: set_code,
        collector_number: collector_number,
        quantity: quantity,
      )
    })
  }
}
