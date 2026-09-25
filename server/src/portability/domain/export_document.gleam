import gleam/list
import gleam/order.{type Order}
import gleam/string
import gleam/time/calendar.{type Date}
import shared/domain/copy_key.{type CopyKey}

// v1 started with the collection alone (#116/#117); #119 widens it with
// inventory_planning and insights sections under this same version (ADR
// 0019). Bump only when a section's shape changes in a way an importer must
// branch on — a new section key does not by itself bump it.
pub const format_version = 1

pub type CollectionEntry {
  CollectionEntry(key: CopyKey, quantity: Int)
}

/// Every set the collection is tracked toward completion for (Insights'
/// target sets, #119). Export always fills this — an empty list means "no
/// targets", same as the app's own empty state.
pub type InsightsSection {
  InsightsSection(target_sets: List(String))
}

pub type ExportDocument {
  ExportDocument(
    exported_on: Date,
    collection: List(CollectionEntry),
    insights: InsightsSection,
  )
}

/// Sorts each section into the file's own deterministic order (ADR 0019),
/// independent of each context's own canonical order — this is Portability's
/// policy, applied so re-exporting unchanged data is byte-identical, which
/// is what makes the round-trip tests possible.
pub fn new(
  exported_on: Date,
  collection: List(CollectionEntry),
  insights: InsightsSection,
) -> ExportDocument {
  ExportDocument(
    exported_on:,
    collection: list.sort(collection, compare),
    insights: InsightsSection(target_sets: list.sort(
      insights.target_sets,
      string.compare,
    )),
  )
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
