import gleam/int
import gleam/option.{None, Some}
import portability/domain/export_document.{
  BulkSpec, CollectionEntry, PlacedEntry, Rule,
}
import portability/domain/import_document.{
  type ImportDocument, BulkSection, CollectionSection, ImportDocument,
  LedgerExcess, MissingCollection, NotJson, NotThisFormat, PlacedSection,
  RawEntry, RawPlaced, RejectedEntry, RulesSection, SectionResult,
  TargetSetsSection, UnsupportedVersion,
}
import shared/domain/copy_key

fn a_raw_entry(
  set_code: String,
  collector_number: String,
  quantity: Int,
  finish: String,
  language: String,
) -> import_document.RawEntry {
  RawEntry(set_code:, collector_number:, quantity:, finish:, language:)
}

fn empty_document() -> ImportDocument {
  ImportDocument(
    collection: [],
    rejected: [],
    target_sets: None,
    rules: None,
    bulk: None,
    placed: None,
  )
}

pub fn a_valid_entry_at_its_position_test() {
  let #(entries, rejected) =
    import_document.validate_entries([a_raw_entry("mh2", "17", 2, "foil", "en")])

  let assert Ok(key) =
    copy_key.new(
      set_code: "mh2",
      collector_number: "17",
      finish: "foil",
      language: "en",
    )
  assert entries == [export_document.CollectionEntry(key:, quantity: 2)]
  assert rejected == []
}

pub fn an_unrecognized_finish_is_rejected_with_its_position_and_identity_test() {
  let #(entries, rejected) =
    import_document.validate_entries([
      a_raw_entry("mh2", "17", 2, "foill", "en"),
    ])

  assert entries == []
  assert rejected
    == [
      RejectedEntry(
        section: CollectionSection,
        position: 1,
        identity: "mh2 17 foill en",
        reason: "unknown finish",
      ),
    ]
}

pub fn a_quantity_below_one_is_rejected_test() {
  let #(entries, rejected) =
    import_document.validate_entries([a_raw_entry("mh2", "17", 0, "foil", "en")])

  assert entries == []
  assert rejected
    == [
      RejectedEntry(
        section: CollectionSection,
        position: 1,
        identity: "mh2 17 foil en",
        reason: "quantity must be at least 1",
      ),
    ]
}

pub fn a_bad_entry_does_not_block_the_rest_and_positions_stay_1_based_test() {
  let #(entries, rejected) =
    import_document.validate_entries([
      a_raw_entry("mh2", "17", 2, "foill", "en"),
      a_raw_entry("dmu", "101", 3, "etched", "zhs"),
    ])

  let assert Ok(dmu_key) =
    copy_key.new(
      set_code: "dmu",
      collector_number: "101",
      finish: "etched",
      language: "zhs",
    )
  assert entries == [export_document.CollectionEntry(key: dmu_key, quantity: 3)]
  assert rejected
    == [
      RejectedEntry(
        section: CollectionSection,
        position: 1,
        identity: "mh2 17 foill en",
        reason: "unknown finish",
      ),
    ]
}

pub fn describes_every_document_error_test() {
  assert import_document.describe_error(NotJson)
    == "The file is not valid JSON."
  assert import_document.describe_error(NotThisFormat)
    == "The file is not a tcg-card-collector export."
  assert import_document.describe_error(MissingCollection)
    == "The file has no \"collection\" array."
  assert import_document.describe_error(UnsupportedVersion("2"))
    == "Unsupported format_version \"2\" — this build reads format_version "
    <> int.to_string(export_document.format_version)
    <> "."
}

pub fn a_valid_target_set_code_at_its_position_test() {
  let #(codes, rejected) = import_document.validate_target_sets(["neo"])

  assert codes == ["neo"]
  assert rejected == []
}

pub fn a_blank_target_set_code_is_rejected_with_its_position_test() {
  let #(codes, rejected) = import_document.validate_target_sets(["neo", "  "])

  assert codes == ["neo"]
  assert rejected
    == [
      RejectedEntry(
        section: TargetSetsSection,
        position: 2,
        identity: "  ",
        reason: "set code is blank",
      ),
    ]
}

fn a_raw_placed(location: String, quantity: Int) -> import_document.RawPlaced {
  RawPlaced(
    set_code: "mh2",
    collector_number: "17",
    finish: "foil",
    language: "en",
    location:,
    quantity:,
  )
}

pub fn a_valid_placed_entry_at_its_position_test() {
  let #(entries, rejected) =
    import_document.validate_placed([a_raw_placed("Box A", 2)])

  let assert Ok(key) =
    copy_key.new(
      set_code: "mh2",
      collector_number: "17",
      finish: "foil",
      language: "en",
    )
  assert entries == [PlacedEntry(key:, location: "Box A", quantity: 2)]
  assert rejected == []
}

pub fn a_blank_placed_location_is_rejected_test() {
  let #(entries, rejected) =
    import_document.validate_placed([a_raw_placed("  ", 1)])

  assert entries == []
  assert rejected
    == [
      RejectedEntry(
        section: PlacedSection,
        position: 1,
        identity: "mh2 17 foil en   ",
        reason: "location is blank",
      ),
    ]
}

fn a_rule(location: String) -> export_document.Rule {
  Rule(location:, expression: "rarity >= rare", selector: "all", sort_keys: "")
}

pub fn a_rule_the_checker_accepts_is_kept_test() {
  let #(valid, rejected) =
    import_document.validate_rules([a_rule("Binder A")], fn(_) { Ok(Nil) })

  assert valid == [a_rule("Binder A")]
  assert rejected == []
}

pub fn a_rule_the_checker_rejects_is_reported_by_location_test() {
  let #(valid, rejected) =
    import_document.validate_rules([a_rule("Binder A")], fn(_) {
      Error("invalid match expression")
    })

  assert valid == []
  assert rejected
    == [
      RejectedEntry(
        section: RulesSection,
        position: 1,
        identity: "Binder A",
        reason: "invalid match expression",
      ),
    ]
}

pub fn an_absent_bulk_spec_stays_absent_test() {
  let #(bulk, rejected) =
    import_document.validate_bulk(None, fn(_) {
      panic as "must not check sort keys for an absent bulk spec"
    })

  assert bulk == None
  assert rejected == []
}

pub fn a_bulk_spec_the_checker_rejects_becomes_none_test() {
  let #(bulk, rejected) =
    import_document.validate_bulk(
      Some(BulkSpec(location: "Bulk", sort_keys: "nope")),
      fn(_) { Error("invalid sort keys") },
    )

  assert bulk == None
  assert rejected
    == [
      RejectedEntry(
        section: BulkSection,
        position: 1,
        identity: "Bulk",
        reason: "invalid sort keys",
      ),
    ]
}

pub fn ledger_excess_reports_only_keys_placed_beyond_what_is_owned_test() {
  let assert Ok(owned_key) =
    copy_key.new(
      set_code: "mh2",
      collector_number: "17",
      finish: "foil",
      language: "en",
    )
  let assert Ok(unowned_key) =
    copy_key.new(
      set_code: "dmu",
      collector_number: "2",
      finish: "nonfoil",
      language: "en",
    )
  let collection = [CollectionEntry(key: owned_key, quantity: 2)]
  let placed = [
    PlacedEntry(key: owned_key, location: "Box A", quantity: 1),
    PlacedEntry(key: owned_key, location: "Box B", quantity: 2),
    PlacedEntry(key: unowned_key, location: "Box A", quantity: 1),
  ]

  assert import_document.ledger_excess(collection, placed)
    == [
      LedgerExcess(identity: "dmu 2 nonfoil en", placed: 1, owned: 0),
      LedgerExcess(identity: "mh2 17 foil en", placed: 3, owned: 2),
    ]
}

pub fn resolve_deep_sections_validates_rules_and_bulk_and_merges_rejections_test() {
  let document =
    ImportDocument(
      ..empty_document(),
      rules: Some([a_rule("Binder A")]),
      bulk: Some(BulkSpec(location: "Bulk", sort_keys: "nope")),
    )

  let resolved =
    import_document.resolve_deep_sections(document, fn(_) { Ok(Nil) }, fn(_) {
      Error("invalid sort keys")
    })

  assert resolved.rules == Some([a_rule("Binder A")])
  assert resolved.bulk == None
  assert resolved.rejected
    == [
      RejectedEntry(
        section: BulkSection,
        position: 1,
        identity: "Bulk",
        reason: "invalid sort keys",
      ),
    ]
}

pub fn section_results_lists_only_sections_present_in_the_document_test() {
  let with_sections =
    ImportDocument(
      ..empty_document(),
      target_sets: Some(["neo"]),
      rules: Some([a_rule("Binder A")]),
      bulk: Some(BulkSpec(location: "Bulk", sort_keys: "")),
      placed: Some([]),
    )

  assert import_document.section_results(with_sections)
    == [
      SectionResult(CollectionSection, 0),
      SectionResult(TargetSetsSection, 1),
      SectionResult(RulesSection, 1),
      SectionResult(BulkSection, 1),
      SectionResult(PlacedSection, 0),
    ]
  assert import_document.section_results(empty_document())
    == [SectionResult(CollectionSection, 0)]
}
