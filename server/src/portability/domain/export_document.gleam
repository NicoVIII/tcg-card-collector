import gleam/list
import gleam/order.{type Order}
import gleam/string
import gleam/time/calendar.{type Date}
import shared/domain/copy_key.{type CopyKey}

// v1 started with the collection alone (#116/#117); #119 widened it with
// inventory_planning and insights sections under that same version (ADR
// 0019). v2 (#122) adds managed locations and lets a placed entry name one —
// a bump even though the change is additive, because ADR 0020's frozen v1
// fixture must keep re-exporting byte-identically under its own version.
pub const format_version = 2

/// The oldest format_version this build still reads (ADR 0020's support
/// window: the current major and the previous one).
pub const oldest_format_version = 1

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

/// Where a placed copy sits: a rule target or bulk by its name (the file's
/// `location` key), or a managed location by *its* name (`managed_location`)
/// — names, not ids, so the file stays hand-editable and a restore can
/// assign fresh ids (ADR 0022).
pub type PlacedIn {
  InLocation(name: String)
  InManagedLocation(name: String)
}

pub type PlacedEntry {
  PlacedEntry(key: CopyKey, location: PlacedIn, quantity: Int)
}

/// A managed location (#122): its name, unique among managed locations, and
/// its kind's text form ("deck"). Its members are their own section, one
/// entry per line, so a 60-card deck doesn't become one 60-card line.
pub type ManagedLocationEntry {
  ManagedLocationEntry(name: String, kind: String)
}

pub type MemberEntry {
  MemberEntry(managed_location: String, key: CopyKey, quantity: Int)
}

/// Rules, bulk spec, managed locations with their members, and the placed
/// ledger (#119, #122). Export always fills this — an empty list means
/// "none", same as the app's own empty state.
pub type InventoryPlanningSection {
  InventoryPlanningSection(
    rules: List(Rule),
    bulk: BulkSpec,
    managed_locations: List(ManagedLocationEntry),
    members: List(MemberEntry),
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
      managed_locations: list.sort(
        inventory_planning.managed_locations,
        fn(a, b) { string.compare(a.name, b.name) },
      ),
      members: list.sort(inventory_planning.members, compare_members),
      placed: list.sort(inventory_planning.placed, compare_placed),
    ),
  )
}

fn compare_members(left: MemberEntry, right: MemberEntry) -> Order {
  string.compare(left.managed_location, right.managed_location)
  |> order.lazy_break_tie(fn() {
    compare(CollectionEntry(left.key, 0), CollectionEntry(right.key, 0))
  })
}

// Cascade locations before managed ones, then by name.
fn compare_placed_in(left: PlacedIn, right: PlacedIn) -> Order {
  case left, right {
    InLocation(a), InLocation(b) -> string.compare(a, b)
    InManagedLocation(a), InManagedLocation(b) -> string.compare(a, b)
    InLocation(_), InManagedLocation(_) -> order.Lt
    InManagedLocation(_), InLocation(_) -> order.Gt
  }
}

fn compare_placed(left: PlacedEntry, right: PlacedEntry) -> Order {
  compare(CollectionEntry(left.key, 0), CollectionEntry(right.key, 0))
  |> order.lazy_break_tie(fn() {
    compare_placed_in(left.location, right.location)
  })
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
