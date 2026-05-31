import domain/card_catalog/card_name
import domain/collection_import/import_source
import domain/collection_import/import_status
import domain/inventory_planning/grouping_strategy
import domain/inventory_planning/location_name
import domain/inventory_planning/sort_strategy
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

pub fn grouping_strategy_roundtrip_test() {
  should.equal(
    grouping_strategy.ByLocation
      |> grouping_strategy.to_string
      |> grouping_strategy.parse,
    Ok(grouping_strategy.ByLocation),
  )
  should.equal(
    grouping_strategy.BySet
      |> grouping_strategy.to_string
      |> grouping_strategy.parse,
    Ok(grouping_strategy.BySet),
  )
  should.equal(
    grouping_strategy.ByCardName
      |> grouping_strategy.to_string
      |> grouping_strategy.parse,
    Ok(grouping_strategy.ByCardName),
  )
}

pub fn sort_strategy_parser_rejects_unknown_values_test() {
  should.equal(
    sort_strategy.parse("unknown"),
    Error(sort_strategy.UnknownSortStrategy),
  )
}

pub fn sort_strategy_roundtrip_test() {
  should.equal(
    sort_strategy.ByCardName |> sort_strategy.to_string |> sort_strategy.parse,
    Ok(sort_strategy.ByCardName),
  )
  should.equal(
    sort_strategy.BySetCode |> sort_strategy.to_string |> sort_strategy.parse,
    Ok(sort_strategy.BySetCode),
  )
  should.equal(
    sort_strategy.ByQuantity |> sort_strategy.to_string |> sort_strategy.parse,
    Ok(sort_strategy.ByQuantity),
  )
}

pub fn import_status_parse_rejects_unknown_values_test() {
  should.equal(
    import_status.parse("unknown"),
    Error(import_status.UnknownImportStatus),
  )
}

pub fn import_status_roundtrip_test() {
  should.equal(
    import_status.Pending
      |> import_status.to_string
      |> import_status.parse,
    Ok(import_status.Pending),
  )
  should.equal(
    import_status.Running
      |> import_status.to_string
      |> import_status.parse,
    Ok(import_status.Running),
  )
  should.equal(
    import_status.Succeeded
      |> import_status.to_string
      |> import_status.parse,
    Ok(import_status.Succeeded),
  )
  should.equal(
    import_status.Failed
      |> import_status.to_string
      |> import_status.parse,
    Ok(import_status.Failed),
  )
}

pub fn location_name_requires_non_empty_value_test() {
  should.equal(location_name.new(""), Error(location_name.EmptyLocationName))
}
