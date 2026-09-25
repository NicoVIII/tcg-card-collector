import collection/driver/gleam/collection_api
import gleam/list
import insights/driver/gleam/insights_api
import portability/application/commands/import_data/ports
import portability/domain/export_document.{type CollectionEntry}

/// Wraps each context's own driver/gleam facade (ADR 0019: Portability
/// reads/writes every context it exports through that context's facade,
/// never its internals). notify_changed is injected from bootstrap so the
/// collection write publishes to the same collection-changed subscriber
/// ImportCollection uses (ADR 0011), rather than this adapter wiring a
/// second one — target-set replacement has no subscriber to notify.
pub fn new(
  notify_changed: fn(Nil) -> Result(Nil, String),
) -> ports.ImportDataPorts {
  ports.ImportDataPorts(
    replace_collection: replace_collection_adapter(notify_changed),
    replace_target_sets: insights_api.replace_target_sets,
  )
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
