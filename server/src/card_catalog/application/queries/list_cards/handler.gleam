import card_catalog/application/queries/list_cards/ports

pub type ListCatalogCardsQuery {
  ListCatalogCardsQuery
}

pub fn execute(
  _query: ListCatalogCardsQuery,
  port: ports.ListCatalogCardsPort,
) -> Result(List(ports.CatalogCardKeyReadModel), String) {
  port.list_cards()
}
