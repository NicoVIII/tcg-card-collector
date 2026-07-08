import card_catalog/application/queries/list_cards/ports
import card_catalog/infrastructure/daos/catalog_dao
import gleam/list
import gleam/result

pub fn new() -> ports.ListCatalogCardsPort {
  ports.ListCatalogCardsPort(list_cards: fn() {
    use rows <- result.map(catalog_dao.list())
    list.map(rows, fn(row) {
      let #(set_code, collector_number) = row
      ports.CatalogCardKeyReadModel(set_code:, collector_number:)
    })
  })
}
