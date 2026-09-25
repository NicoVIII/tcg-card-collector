import collection/driver/gleam/collection_api
import gleam/list
import portability/application/commands/import_data/ports
import portability/domain/export_document.{type CollectionEntry}

/// Wraps Collection's replace_copies (ADR 0019: Portability reads/writes
/// every context it exports through that context's driver/gleam facade,
/// never its internals). notify_changed is injected from bootstrap so this
/// write path publishes to the same collection-changed subscriber
/// ImportCollection uses (ADR 0011), rather than this adapter wiring a
/// second one.
pub fn new(
  notify_changed: fn(Nil) -> Result(Nil, String),
) -> ports.ImportDataPorts {
  ports.ImportDataPorts(replace_collection: replace_collection_adapter(
    notify_changed,
  ))
}

fn replace_collection_adapter(
  notify_changed: fn(Nil) -> Result(Nil, String),
) -> ports.ReplaceCollectionPort {
  fn(entries) {
    collection_api.replace_copies(
      list.map(entries, to_owned_copy),
      notify_changed,
    )
  }
}

fn to_owned_copy(entry: CollectionEntry) -> collection_api.OwnedCopy {
  collection_api.OwnedCopy(key: entry.key, quantity: entry.quantity)
}
