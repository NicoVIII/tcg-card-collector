import card_catalog/application/queries/get_cards/ports

pub type GetCatalogCardsQuery {
  GetCatalogCardsQuery(keys: List(#(String, String)))
}

pub fn execute(
  query: GetCatalogCardsQuery,
  port: ports.GetCatalogCardsPort,
) -> Result(List(ports.CardReadModel), String) {
  port.get_cards(query.keys)
}
