import catalog/application/queries/get_cards/ports
import catalog/infrastructure/daos/catalog_dao
import gleam/list

pub fn new() -> ports.GetCatalogCardsPort {
  ports.GetCatalogCardsPort(get_cards: get_cards_adapter())
}

fn get_cards_adapter() -> fn(List(#(String, String))) ->
  List(ports.CardReadModel) {
  fn(keys) {
    catalog_dao.get_by_keys(keys)
    |> list.map(fn(row) {
      let #(set_code, collector_number, name, image_uri) = row
      ports.CardReadModel(set_code:, collector_number:, name:, image_uri:)
    })
  }
}
