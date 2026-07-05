import collection/application/queries/list_cards/ports
import collection/infrastructure/daos/collection_dao
import gleam/list
import gleam/result

pub fn new() -> ports.ListCollectionCardsPort {
  ports.ListCollectionCardsPort(list_cards: list_cards_adapter())
}

fn list_cards_adapter() -> fn() ->
  Result(List(ports.CollectionCardReadModel), String) {
  fn() {
    use rows <- result.try(collection_dao.list_cards())
    Ok(
      list.map(rows, fn(row) {
        let #(set_code, collector_number, quantity) = row
        ports.CollectionCardReadModel(
          set_code: set_code,
          collector_number: collector_number,
          quantity: quantity,
        )
      }),
    )
  }
}
