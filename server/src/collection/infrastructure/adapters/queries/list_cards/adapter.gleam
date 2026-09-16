import collection/application/queries/list_cards/ports
import collection/infrastructure/daos/collection_dao
import gleam/list
import gleam/result
import shared/domain/copy_key

pub fn new() -> ports.ListCollectionCardsPort {
  ports.ListCollectionCardsPort(list_cards: list_cards_adapter())
}

fn list_cards_adapter() -> fn() ->
  Result(List(ports.CollectionCopyReadModel), String) {
  fn() {
    use rows <- result.try(collection_dao.list_cards())
    // Stored rows were written from a CopyKey, so they parse with the strict
    // constructor; a failure means corrupt stored data and fails the query
    // (ADR 0008).
    list.try_map(rows, fn(row) {
      let collection_dao.CardRow(
        set_code:,
        collector_number:,
        finish:,
        language:,
        quantity:,
      ) = row
      case copy_key.new(set_code:, collector_number:, finish:, language:) {
        Ok(key) -> Ok(ports.CollectionCopyReadModel(key:, quantity:))
        Error(error) ->
          Error(
            "corrupt collection row "
            <> set_code
            <> "/"
            <> collector_number
            <> ": "
            <> copy_key.describe_error(error),
          )
      }
    })
  }
}
