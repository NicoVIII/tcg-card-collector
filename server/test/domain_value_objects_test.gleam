import domain/card_catalog/card_name
import domain/collection_import/import_source
import domain/collection_import/import_status
import domain/inventory_planning/grouping_strategy
import domain/inventory_planning/location_name
import gleeunit
import gleeunit/should

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn card_name_requires_non_empty_value_test() {
  should.equal(card_name.new(""), Error(card_name.EmptyCardName))
}

pub fn import_source_requires_non_empty_file_name_test() {
  should.equal(
    import_source.new(""),
    Error(import_source.EmptyImportSourceFileName),
  )
}

pub fn import_status_allows_running_to_succeeded_transition_test() {
  should.equal(
    import_status.can_transition(import_status.Running, import_status.Succeeded),
    True,
  )
}

pub fn import_status_rejects_pending_to_succeeded_transition_test() {
  should.equal(
    import_status.can_transition(import_status.Pending, import_status.Succeeded),
    False,
  )
}

pub fn grouping_strategy_parser_rejects_unknown_values_test() {
  should.equal(
    grouping_strategy.parse("unknown"),
    Error(grouping_strategy.UnknownGroupingStrategy),
  )
}

pub fn location_name_requires_non_empty_value_test() {
  should.equal(location_name.new(""), Error(location_name.EmptyLocationName))
}
