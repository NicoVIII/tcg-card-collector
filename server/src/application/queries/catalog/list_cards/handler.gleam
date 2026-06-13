import application/queries/catalog/list_cards/ports

pub type ListCatalogCardsQuery {
  ListCatalogCardsQuery
}

pub fn execute(
  _query: ListCatalogCardsQuery,
  port: ports.ListCatalogCardsPort,
) -> List(ports.CatalogCardReadModel) {
  port.list_cards()
}
