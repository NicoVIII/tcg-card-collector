import gleam/list
import gleam/order.{type Order}
import gleam/string
import gleam/time/calendar.{type Date}
import shared/domain/copy_key.{type CopyKey}

// v1 covers the collection alone; #119 adds inventory_planning and insights
// sections under this same version (ADR 0019). Bump only when a section's
// shape changes in a way an importer must branch on.
pub const format_version = 1

pub type CollectionEntry {
  CollectionEntry(key: CopyKey, quantity: Int)
}

pub type ExportDocument {
  ExportDocument(exported_on: Date, collection: List(CollectionEntry))
}

/// Sorts the collection into the file's own deterministic order (ADR 0019),
/// independent of Inventory Planning's canonical claim order — this is
/// Portability's policy, applied so re-exporting an unchanged collection is
/// byte-identical, which is what makes #117's round-trip test possible.
pub fn new(
  exported_on: Date,
  collection: List(CollectionEntry),
) -> ExportDocument {
  ExportDocument(exported_on:, collection: list.sort(collection, compare))
}

fn compare(left: CollectionEntry, right: CollectionEntry) -> Order {
  string.compare(
    copy_key.set_code_string(left.key),
    copy_key.set_code_string(right.key),
  )
  |> order.lazy_break_tie(fn() {
    string.compare(
      copy_key.collector_number_string(left.key),
      copy_key.collector_number_string(right.key),
    )
  })
  |> order.lazy_break_tie(fn() {
    string.compare(
      copy_key.finish_string(left.key),
      copy_key.finish_string(right.key),
    )
  })
  |> order.lazy_break_tie(fn() {
    string.compare(
      copy_key.language_string(left.key),
      copy_key.language_string(right.key),
    )
  })
}
