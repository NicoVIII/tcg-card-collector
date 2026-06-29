import catalog/application/queries/get_cards/ports

pub type GetCatalogCardsQuery {
  GetCatalogCardsQuery(keys: List(#(String, String)))
}

pub fn execute(
  query: GetCatalogCardsQuery,
  port: ports.GetCatalogCardsPort,
) -> List(ports.CardReadModel) {
  port.get_cards(query.keys)
}
