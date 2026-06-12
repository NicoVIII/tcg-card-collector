pub type ListCardsPort {
  ListCardsPort(list_cards: fn() -> List(DatabaseCardReadModel))
}

pub type DatabaseCardReadModel {
  DatabaseCardReadModel(id: String, name: String, set_code: String)
}
