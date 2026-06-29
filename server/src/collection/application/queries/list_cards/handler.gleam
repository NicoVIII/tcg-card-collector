import collection/application/queries/list_cards/ports

pub type ListCollectionCardsQuery {
  ListCollectionCardsQuery
}

pub fn execute(
  _query: ListCollectionCardsQuery,
  port: ports.ListCollectionCardsPort,
) -> List(ports.CollectionCardReadModel) {
  port.list_cards()
}
