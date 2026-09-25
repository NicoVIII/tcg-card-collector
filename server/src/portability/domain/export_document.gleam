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

/// One location rule's four hand-authored fields, in the canonical DSL text
/// the location cascade already stores (Inventory Planning's own
/// `driver/gleam` facade, #119) — round-trips through that context's own
/// parser/printer, never re-interpreted by Portability. Carries no id: the
/// cascade position is the list's own order.
pub type Rule {
  Rule(
    location: String,
    expression: String,
    selector: String,
    sort_keys: String,
  )
}

pub type BulkSpec {
  BulkSpec(location: String, sort_keys: String)
}

pub type PlacedEntry {
  PlacedEntry(key: CopyKey, location: String, quantity: Int)
}

/// Rules, bulk spec, and the placed ledger (#119). Export always fills this
/// — an empty `rules`/`placed` list means "none", same as the app's own
/// empty state.
pub type InventoryPlanningSection {
  InventoryPlanningSection(
    rules: List(Rule),
    bulk: BulkSpec,
    placed: List(PlacedEntry),
  )
}

pub type ExportDocument {
  ExportDocument(
    exported_on: Date,
    collection: List(CollectionEntry),
    insights: InsightsSection,
    inventory_planning: InventoryPlanningSection,
  )
}

/// Sorts each section into the file's own deterministic order (ADR 0019),
/// independent of each context's own canonical order — this is Portability's
/// policy, applied so re-exporting unchanged data is byte-identical, which
/// is what makes the round-trip tests possible. Rules are the one exception:
/// their array order *is* the cascade position, so it is kept exactly as
/// given, not re-sorted.
pub fn new(
  exported_on: Date,
  collection: List(CollectionEntry),
  insights: InsightsSection,
  inventory_planning: InventoryPlanningSection,
) -> ExportDocument {
  ExportDocument(
    exported_on:,
    collection: list.sort(collection, compare),
    insights: InsightsSection(target_sets: list.sort(
      insights.target_sets,
      string.compare,
    )),
    inventory_planning: InventoryPlanningSection(
      rules: inventory_planning.rules,
      bulk: inventory_planning.bulk,
      placed: list.sort(inventory_planning.placed, compare_placed),
    ),
  )
}

fn compare_placed(left: PlacedEntry, right: PlacedEntry) -> Order {
  compare(CollectionEntry(left.key, 0), CollectionEntry(right.key, 0))
  |> order.lazy_break_tie(fn() { string.compare(left.location, right.location) })
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
