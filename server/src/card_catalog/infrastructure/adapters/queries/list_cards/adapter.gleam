import card_catalog/application/queries/list_cards/ports
import card_catalog/infrastructure/daos/catalog_dao
import gleam/list

pub fn new() -> ports.ListCatalogCardsPort {
  ports.ListCatalogCardsPort(list_cards: fn() {
    catalog_dao.list()
    |> list.map(fn(row) {
      let #(set_code, collector_number) = row
      ports.CatalogCardKeyReadModel(set_code:, collector_number:)
    })
  })
}
