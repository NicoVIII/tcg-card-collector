import gleam/time/calendar
import portability/domain/export_document.{
  type InsightsSection, type InventoryPlanningSection, BulkSpec, CollectionEntry,
  InsightsSection, InventoryPlanningSection, PlacedEntry,
}
import shared/domain/copy_key

fn entry(
  set_code: String,
  collector_number: String,
  finish: String,
  language: String,
) -> export_document.CollectionEntry {
  let assert Ok(key) =
    copy_key.new(set_code:, collector_number:, finish:, language:)
  CollectionEntry(key:, quantity: 1)
}

fn no_targets() -> InsightsSection {
  InsightsSection(target_sets: [])
}

fn no_plan() -> InventoryPlanningSection {
  InventoryPlanningSection(
    rules: [],
    bulk: BulkSpec(location: "Bulk", sort_keys: ""),
    placed: [],
  )
}

pub fn sorts_by_set_code_then_collector_number_then_finish_then_language_test() {
  let unsorted = [
    entry("mh2", "17", "foil", "en"),
    entry("dmu", "101", "nonfoil", "en"),
    entry("dmu", "101", "nonfoil", "de"),
    entry("dmu", "2", "nonfoil", "en"),
  ]

  let document =
    export_document.new(
      calendar.Date(2026, calendar.September, 25),
      unsorted,
      no_targets(),
      no_plan(),
    )

  assert document.collection
    == [
      entry("dmu", "101", "nonfoil", "de"),
      entry("dmu", "101", "nonfoil", "en"),
      entry("dmu", "2", "nonfoil", "en"),
      entry("mh2", "17", "foil", "en"),
    ]
}

pub fn an_empty_collection_stays_empty_test() {
  let document =
    export_document.new(
      calendar.Date(2026, calendar.September, 25),
      [],
      no_targets(),
      no_plan(),
    )

  assert document.collection == []
}

pub fn target_sets_are_sorted_test() {
  let document =
    export_document.new(
      calendar.Date(2026, calendar.September, 25),
      [],
      InsightsSection(target_sets: ["neo", "2xm", "lea"]),
      no_plan(),
    )

  assert document.insights
    == InsightsSection(target_sets: ["2xm", "lea", "neo"])
}

pub fn rules_keep_their_given_order_while_placed_is_sorted_test() {
  let assert Ok(mh2_key) =
    copy_key.new(
      set_code: "mh2",
      collector_number: "17",
      finish: "foil",
      language: "en",
    )
  let assert Ok(dmu_key) =
    copy_key.new(
      set_code: "dmu",
      collector_number: "2",
      finish: "nonfoil",
      language: "en",
    )
  let rules = [
    export_document.Rule(
      location: "Binder B",
      expression: "rarity >= rare",
      selector: "all",
      sort_keys: "",
    ),
    export_document.Rule(
      location: "Binder A",
      expression: "rarity >= mythic",
      selector: "all",
      sort_keys: "",
    ),
  ]
  let unsorted_placed = [
    PlacedEntry(key: mh2_key, location: "Box", quantity: 1),
    PlacedEntry(key: dmu_key, location: "Box", quantity: 2),
  ]

  let document =
    export_document.new(
      calendar.Date(2026, calendar.September, 25),
      [],
      no_targets(),
      InventoryPlanningSection(
        rules:,
        bulk: BulkSpec(location: "Bulk", sort_keys: ""),
        placed: unsorted_placed,
      ),
    )

  // Position, not alphabetical order: "Binder B" stays first.
  assert document.inventory_planning.rules == rules
  assert document.inventory_planning.placed
    == [
      PlacedEntry(key: dmu_key, location: "Box", quantity: 2),
      PlacedEntry(key: mh2_key, location: "Box", quantity: 1),
    ]
}
