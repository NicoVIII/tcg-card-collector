import shared/domain/copy_key.{type CopyKey}

pub type ImportCollectionRow {
  ImportCollectionRow(
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

pub type ReplaceCollectionPort =
  fn(List(CollectionRowWriteModel)) -> Result(Nil, String)

pub type ImportCollectionError {
  InvalidRows
  PersistenceFailed(reason: String)
}
