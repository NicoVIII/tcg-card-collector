import shared/domain/card_key.{type CardKey}

pub type ImportCollectionRow {
  ImportCollectionRow(set_code: String, collector_number: String, quantity: Int)
}

pub type CollectionRowWriteModel {
  CollectionRowWriteModel(key: CardKey, quantity: Int)
}

pub type ReplaceCollectionPort =
  fn(List(CollectionRowWriteModel)) -> Result(Nil, String)

pub type ImportCollectionError {
  InvalidRows
  PersistenceFailed(reason: String)
}
