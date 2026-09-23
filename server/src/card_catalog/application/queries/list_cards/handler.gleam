import card_catalog/application/queries/list_cards/ports

pub type ListCatalogCardsQuery {
  ListCatalogCardsQuery(filter: ports.CatalogCardFilter)
}

pub fn execute(
  query: ListCatalogCardsQuery,
  port: ports.ListCatalogCardsPort,
) -> Result(List(ports.CatalogCardKeyReadModel), String) {
  port.list_cards(query.filter)
}
