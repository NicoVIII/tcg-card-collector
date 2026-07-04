import gleam/dict.{type Dict}

pub type TargetSetsPort =
  fn() -> List(String)

pub type SetCardKeysPort =
  fn(List(String)) -> Dict(String, List(String))

pub type OwnedCard {
  OwnedCard(set_code: String, collector_number: String)
}

pub type OwnedCardsPort =
  fn() -> List(OwnedCard)

pub type SetCompletionReadModel {
  SetCompletionReadModel(set_code: String, owned: Int, total: Int)
}

pub type SetCompletionPorts {
  SetCompletionPorts(
    target_sets: TargetSetsPort,
    set_card_keys: SetCardKeysPort,
    owned_cards: OwnedCardsPort,
  )
}
