import shared/domain/copy_key.{type CopyKey}

pub type RemoveCardsRow {
  RemoveCardsRow(
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

/// How many copies of one key the collection holds; 0 when none.
pub type OwnedQuantityPort =
  fn(CopyKey) -> Result(Int, String)

pub type DecrementCardsPort =
  fn(List(CollectionRowWriteModel)) -> Result(Nil, String)

/// Fires after a successful decrement so a subscriber (Inventory Planning's
/// placed-ledger reconciliation) can react to owned quantities having
/// shrunk. The result is deliberately ignored by the handler — ADR 0011.
pub type NotifyCollectionChangedPort =
  fn(Nil) -> Result(Nil, String)

pub type RemoveCardsPorts {
  RemoveCardsPorts(
    owned_quantity: OwnedQuantityPort,
    decrement_cards: DecrementCardsPort,
    notify_changed: NotifyCollectionChangedPort,
  )
}

pub type RemoveCardsError {
  InvalidRows
  /// A staged key isn't owned, or not in the staged quantity — the client
  /// prevents this at staging time, so it only arises from a stale page.
  ExceedsOwned
  PersistenceFailed(reason: String)
}
