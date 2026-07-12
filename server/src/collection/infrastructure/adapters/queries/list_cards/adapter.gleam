import collection/application/queries/list_cards/ports
import collection/infrastructure/daos/collection_dao
import gleam/list
import gleam/result
import shared/domain/card_key

pub fn new() -> ports.ListCollectionCardsPort {
  ports.ListCollectionCardsPort(list_cards: list_cards_adapter())
}

fn list_cards_adapter() -> fn() ->
  Result(List(ports.CollectionCardReadModel), String) {
  fn() {
    use rows <- result.try(collection_dao.list_cards())
    // Stored rows were written from a CardKey, so they parse with the strict
    // constructor; a failure means corrupt stored data and fails the query
    // (ADR 0008).
    list.try_map(rows, fn(row) {
      let #(set_code, collector_number, quantity) = row
      case card_key.new(set_code:, collector_number:) {
        Ok(key) -> Ok(ports.CollectionCardReadModel(key:, quantity:))
        Error(error) ->
          Error(
            "corrupt collection row "
            <> set_code
            <> "/"
            <> collector_number
            <> ": "
            <> card_key.describe_error(error),
          )
      }
    })
  }
}
