import gleam/time/calendar
import portability/domain/export_document.{
  type InsightsSection, CollectionEntry, InsightsSection,
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
    )

  assert document.collection == []
}

pub fn target_sets_are_sorted_test() {
  let document =
    export_document.new(
      calendar.Date(2026, calendar.September, 25),
      [],
      InsightsSection(target_sets: ["neo", "2xm", "lea"]),
    )

  assert document.insights
    == InsightsSection(target_sets: ["2xm", "lea", "neo"])
}
