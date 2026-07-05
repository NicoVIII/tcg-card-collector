import shared/domain/card_key.{type CardKey}

pub type AddCardsRow {
  AddCardsRow(set_code: String, collector_number: String, quantity: Int)
}

pub type CollectionRowWriteModel {
  CollectionRowWriteModel(key: CardKey, quantity: Int)
}

pub type UpsertCardsPort =
  fn(List(CollectionRowWriteModel)) -> Result(Nil, String)

pub type AddCardsError {
  InvalidRows
  PersistenceFailed(reason: String)
}
