import gleam/list
import gleam/option.{None, Some}
import portability/application/commands/import_data/handler
import portability/application/commands/import_data/ports
import portability/domain/export_document.{InLocation, Rule}
import portability/domain/import_document.{
  type ImportDocument, type LedgerPrune, AuditsSection, BulkSection,
  CollectionSection, ImportDocument, LedgerPrune, ManagedLocationsSection,
  PlacedSection, RulesSection, SectionResult, TargetSetsSection,
}
import shared/domain/copy_key
import support/ref

fn an_entry(quantity: Int) -> export_document.CollectionEntry {
  let assert Ok(key) =
    copy_key.new(
      set_code: "mh2",
      collector_number: "17",
      finish: "nonfoil",
      language: "en",
    )
  export_document.CollectionEntry(key:, quantity:)
}

fn empty_document() -> ImportDocument {
  ImportDocument(
    collection: [],
    rejected: [],
    target_sets: None,
    rules: None,
    bulk: None,
    managed_locations: None,
    members: None,
    placed: None,
    audits: None,
  )
}

fn a_rule() -> export_document.Rule {
  Rule(
    location: "Binder A",
    expression: "rarity >= rare",
    selector: "all",
    sort_keys: "",
  )
}

// Every write records the section(s) it touched onto `written`, so a test
// can assert on the resulting order without spying on call counts.
fn build_ports(
  written written: ref.Ref(List(import_document.Section)),
  check_rule_result check_rule_result: Result(Nil, String),
  replace_target_sets_result replace_target_sets_result: Result(Nil, String),
  replace_plan_result replace_plan_result: Result(Nil, String),
  replace_collection_result replace_collection_result: Result(Nil, String),
) -> ports.ImportDataPorts {
  ports.ImportDataPorts(
    check_rule: fn(_rule) { check_rule_result },
    check_bulk_spec: fn(_raw) { Ok(Nil) },
    check_managed_kind: fn(_kind) { Ok(Nil) },
    replace_target_sets: fn(_codes) {
      record_if_ok(written, [TargetSetsSection], replace_target_sets_result)
    },
    replace_plan: fn(rules, bulk, managed, placed, audits) {
      let sections =
        [
          option.map(rules, fn(_) { RulesSection }),
          option.map(bulk, fn(_) { BulkSection }),
          option.map(managed, fn(_) { ManagedLocationsSection }),
          option.map(placed, fn(_) { PlacedSection }),
          option.map(audits, fn(_) { AuditsSection }),
        ]
        |> option.values
      record_if_ok(written, sections, replace_plan_result)
    },
    replace_collection: fn(_entries) {
      record_if_ok(written, [CollectionSection], replace_collection_result)
    },
    predict_prune: fn(_collection, _managed, _placed) { Ok([]) },
  )
}

fn record_if_ok(
  written: ref.Ref(List(import_document.Section)),
  sections: List(import_document.Section),
  result: Result(Nil, String),
) -> Result(Nil, String) {
  case result {
    Ok(Nil) -> {
      ref.set(written, list.append(ref.get(written), sections))
      Ok(Nil)
    }
    Error(reason) -> Error(reason)
  }
}

pub fn an_empty_document_is_rejected_without_writing_any_section_test() {
  let written = ref.new([])
  let document =
    ImportDocument(
      ..empty_document(),
      target_sets: Some(["neo"]),
      rules: Some([a_rule()]),
    )
  let import_ports =
    build_ports(
      written:,
      check_rule_result: Ok(Nil),
      replace_target_sets_result: Ok(Nil),
      replace_plan_result: Ok(Nil),
      replace_collection_result: Ok(Nil),
    )

  let result =
    handler.execute(handler.ImportDataCommand(document:), import_ports)

  assert result == Error(ports.NothingToImport)
  assert ref.get(written) == []
}

pub fn valid_entries_alone_replace_only_the_collection_test() {
  let written = ref.new([])
  let document = ImportDocument(..empty_document(), collection: [an_entry(2)])
  let import_ports =
    build_ports(
      written:,
      check_rule_result: Ok(Nil),
      replace_target_sets_result: Ok(Nil),
      replace_plan_result: Ok(Nil),
      replace_collection_result: Ok(Nil),
    )

  let result =
    handler.execute(handler.ImportDataCommand(document:), import_ports)

  assert result
    == Ok(
      handler.ImportResult(
        sections: [SectionResult(CollectionSection, 1)],
        pruned: [],
      ),
    )
  assert ref.get(written) == [CollectionSection]
}

pub fn target_sets_and_the_plan_write_before_the_collection_test() {
  let written = ref.new([])
  let document =
    ImportDocument(
      collection: [an_entry(1)],
      rejected: [],
      target_sets: Some(["neo"]),
      rules: Some([a_rule()]),
      bulk: None,
      managed_locations: None,
      members: None,
      placed: Some([]),
      audits: None,
    )
  let import_ports =
    build_ports(
      written:,
      check_rule_result: Ok(Nil),
      replace_target_sets_result: Ok(Nil),
      replace_plan_result: Ok(Nil),
      replace_collection_result: Ok(Nil),
    )

  let result =
    handler.execute(handler.ImportDataCommand(document:), import_ports)

  assert result
    == Ok(
      handler.ImportResult(
        sections: [
          SectionResult(CollectionSection, 1),
          SectionResult(TargetSetsSection, 1),
          SectionResult(RulesSection, 1),
          SectionResult(PlacedSection, 0),
        ],
        pruned: [],
      ),
    )
  assert ref.get(written)
    == [TargetSetsSection, RulesSection, PlacedSection, CollectionSection]
}

pub fn a_rule_the_checker_rejects_is_dropped_before_the_plan_writes_test() {
  let written = ref.new([])
  let document =
    ImportDocument(
      ..empty_document(),
      collection: [an_entry(1)],
      rules: Some([a_rule()]),
    )
  let import_ports =
    build_ports(
      written:,
      check_rule_result: Error("invalid match expression"),
      replace_target_sets_result: Ok(Nil),
      replace_plan_result: Ok(Nil),
      replace_collection_result: Ok(Nil),
    )

  let result =
    handler.execute(handler.ImportDataCommand(document:), import_ports)

  assert result
    == Ok(
      handler.ImportResult(
        sections: [
          SectionResult(CollectionSection, 1),
          SectionResult(RulesSection, 0),
        ],
        pruned: [],
      ),
    )
}

pub fn a_persistence_failure_before_any_section_writes_is_reported_plainly_test() {
  let written = ref.new([])
  let document = ImportDocument(..empty_document(), collection: [an_entry(1)])
  let import_ports =
    build_ports(
      written:,
      check_rule_result: Ok(Nil),
      replace_target_sets_result: Ok(Nil),
      replace_plan_result: Ok(Nil),
      replace_collection_result: Error("db down"),
    )

  let result =
    handler.execute(handler.ImportDataCommand(document:), import_ports)

  assert result == Error(ports.PersistenceFailed("db down"))
}

pub fn a_failure_after_an_earlier_section_wrote_names_what_was_written_test() {
  let written = ref.new([])
  let document =
    ImportDocument(
      ..empty_document(),
      collection: [an_entry(1)],
      target_sets: Some(["neo"]),
    )
  let import_ports =
    build_ports(
      written:,
      check_rule_result: Ok(Nil),
      replace_target_sets_result: Ok(Nil),
      replace_plan_result: Ok(Nil),
      replace_collection_result: Error("db down"),
    )

  let result =
    handler.execute(handler.ImportDataCommand(document:), import_ports)

  assert result
    == Error(ports.PartiallyWritten(
      written: [TargetSetsSection],
      reason: "db down",
    ))
  assert ref.get(written) == [TargetSetsSection]
}

fn ok_ports(
  written: ref.Ref(List(import_document.Section)),
) -> ports.ImportDataPorts {
  build_ports(
    written:,
    check_rule_result: Ok(Nil),
    replace_target_sets_result: Ok(Nil),
    replace_plan_result: Ok(Nil),
    replace_collection_result: Ok(Nil),
  )
}

fn a_prune() -> LedgerPrune {
  LedgerPrune(
    identity: "mh2 17 nonfoil en",
    location: InLocation("Binder A"),
    quantity: 1,
  )
}

pub fn the_result_lists_the_ledger_rows_the_import_prunes_test() {
  // arrange
  let written = ref.new([])
  let document = ImportDocument(..empty_document(), collection: [an_entry(1)])
  let import_ports =
    ports.ImportDataPorts(..ok_ports(written), predict_prune: fn(_, _, _) {
      Ok([a_prune()])
    })

  // act
  let result =
    handler.execute(handler.ImportDataCommand(document:), import_ports)

  // assert
  assert result
    == Ok(
      handler.ImportResult(
        sections: [SectionResult(CollectionSection, 1)],
        pruned: [a_prune()],
      ),
    )
}

pub fn the_prune_is_predicted_from_the_sections_the_import_writes_test() {
  // arrange
  let written = ref.new([])
  let asked = ref.new(None)
  let placed = [
    export_document.PlacedEntry(
      key: an_entry(1).key,
      location: InLocation("Binder A"),
      quantity: 2,
    ),
  ]
  let document =
    ImportDocument(
      ..empty_document(),
      collection: [an_entry(1)],
      placed: Some(placed),
    )
  let import_ports =
    ports.ImportDataPorts(
      ..ok_ports(written),
      predict_prune: fn(collection, managed, placed) {
        ref.set(asked, Some(#(collection, managed, placed)))
        Ok([])
      },
    )

  // act
  let _ = handler.execute(handler.ImportDataCommand(document:), import_ports)

  // assert
  assert ref.get(asked) == Some(#([an_entry(1)], None, Some(placed)))
}

pub fn a_failed_prune_prediction_stops_the_import_before_any_write_test() {
  // arrange
  let written = ref.new([])
  let document =
    ImportDocument(
      ..empty_document(),
      collection: [an_entry(1)],
      target_sets: Some(["neo"]),
    )
  let import_ports =
    ports.ImportDataPorts(..ok_ports(written), predict_prune: fn(_, _, _) {
      Error("db down")
    })

  // act
  let result =
    handler.execute(handler.ImportDataCommand(document:), import_ports)

  // assert
  assert result == Error(ports.PersistenceFailed("db down"))
  assert ref.get(written) == []
}
