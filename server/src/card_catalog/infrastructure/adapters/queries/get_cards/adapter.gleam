import card_catalog/application/queries/get_cards/ports
import card_catalog/infrastructure/daos/catalog_dao
import gleam/list
import gleam/result

pub fn new() -> ports.GetCatalogCardsPort {
  ports.GetCatalogCardsPort(get_cards: get_cards_adapter())
}

fn get_cards_adapter() -> fn(List(#(String, String))) ->
  Result(List(ports.CardReadModel), String) {
  fn(keys) {
    use rows <- result.map(catalog_dao.get_by_keys(keys))
    list.map(rows, fn(row) {
      let #(
        set_code,
        collector_number,
        name,
        image_uri,
        rarity,
        oracle_id,
        color_identity,
        type_line,
        released_at,
      ) = row
      ports.CardReadModel(
        set_code:,
        collector_number:,
        name:,
        image_uri:,
        rarity:,
        oracle_id:,
        color_identity:,
        type_line:,
        released_at:,
      )
    })
  }
}
