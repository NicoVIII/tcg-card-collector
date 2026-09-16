import shared/domain/copy_key.{type CopyKey}

pub type AddCardsRow {
  AddCardsRow(
    set_code: String,
    collector_number: String,
    finish: String,
    language: String,
    quantity: Int,
  )
}

pub type CollectionRowWriteModel {
  CollectionRowWriteModel(key: CopyKey, quantity: Int)
}

pub type UpsertCardsPort =
  fn(List(CollectionRowWriteModel)) -> Result(Nil, String)

pub type AddCardsError {
  InvalidRows
  PersistenceFailed(reason: String)
}
