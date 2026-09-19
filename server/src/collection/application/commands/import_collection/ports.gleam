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

/// Fires after a successful replace so a subscriber (Inventory Planning's
/// placed-ledger reconciliation) can react to owned quantities having
/// shrunk. The result is deliberately ignored by the handler — ADR 0011.
pub type NotifyCollectionChangedPort =
  fn(Nil) -> Result(Nil, String)

pub type ImportCollectionPorts {
  ImportCollectionPorts(
    replace_collection: ReplaceCollectionPort,
    notify_changed: NotifyCollectionChangedPort,
  )
}

pub type ImportCollectionError {
  InvalidRows
  PersistenceFailed(reason: String)
}
