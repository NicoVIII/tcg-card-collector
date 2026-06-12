import application/queries/database/list_cards/ports

pub type ListDatabaseCardsQuery {
  ListDatabaseCardsQuery
}

pub fn execute(
  _query: ListDatabaseCardsQuery,
  port: ports.ListCardsPort,
) -> List(ports.DatabaseCardReadModel) {
  port.list_cards()
}
