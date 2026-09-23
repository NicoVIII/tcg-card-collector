import card_catalog/application/queries/list_cards/ports
import card_catalog/infrastructure/daos/catalog_dao
import gleam/list
import gleam/option
import gleam/result
import shared/domain/set_code

pub fn new() -> ports.ListCatalogCardsPort {
  ports.ListCatalogCardsPort(list_cards: fn(filter) {
    use rows <- result.map(catalog_dao.list(
      filter.name,
      option.map(filter.set_code, set_code.to_string),
    ))
    list.map(rows, fn(row) {
      let #(set_code, collector_number) = row
      ports.CatalogCardKeyReadModel(set_code:, collector_number:)
    })
  })
}
