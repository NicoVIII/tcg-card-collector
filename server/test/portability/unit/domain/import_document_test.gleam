import gleam/int
import gleam/option.{None, Some}
import gleam/set
import portability/domain/export_document.{
  BulkSpec, CollectionEntry, InLocation, InManagedLocation, ManagedLocationEntry,
  MemberEntry, PlacedEntry, Rule,
}
import portability/domain/import_document.{
  type ImportDocument, BulkSection, CollectionSection, ImportDocument,
  LedgerExcess, ManagedLocationsSection, ManagedShortfall, MembersSection,
  MissingCollection, NotJson, NotThisFormat, PlacedSection, RawEntry,
  RawManagedLocation, RawMember, RawPlaced, RejectedEntry, RulesSection,
  SectionResult, TargetSetsSection, UnsupportedVersion,
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
    managed_locations: None,
    members: None,
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
  assert import_document.describe_error(UnsupportedVersion("9"))
    == "Unsupported format_version \"9\" — this build reads format_version "
    <> int.to_string(export_document.oldest_format_version)
    <> " through "
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

pub fn target_set_codes_import_canonically_and_a_respelling_is_rejected_test() {
  let #(codes, rejected) =
    import_document.validate_target_sets([" GRN ", "neo", "grn"])

  assert codes == ["grn", "neo"]
  assert rejected
    == [
      RejectedEntry(
        section: TargetSetsSection,
        position: 3,
        identity: "grn",
        reason: "set code is listed twice",
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
    managed_location: "",
    quantity:,
  )
}

pub fn a_valid_placed_entry_at_its_position_test() {
  let #(entries, rejected) =
    import_document.validate_placed([a_raw_placed("Box A", 2)], set.new())

  let assert Ok(key) =
    copy_key.new(
      set_code: "mh2",
      collector_number: "17",
      finish: "foil",
      language: "en",
    )
  assert entries
    == [
      PlacedEntry(
        key:,
        location: export_document.InLocation("Box A"),
        quantity: 2,
      ),
    ]
  assert rejected == []
}

pub fn a_blank_placed_location_is_rejected_test() {
  let #(entries, rejected) =
    import_document.validate_placed([a_raw_placed("  ", 1)], set.new())

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
    PlacedEntry(
      key: owned_key,
      location: export_document.InLocation("Box A"),
      quantity: 1,
    ),
    PlacedEntry(
      key: owned_key,
      location: export_document.InLocation("Box B"),
      quantity: 2,
    ),
    PlacedEntry(
      key: unowned_key,
      location: export_document.InLocation("Box A"),
      quantity: 1,
    ),
  ]

  assert import_document.ledger_excess(collection, placed)
    == [
      LedgerExcess(identity: "dmu 2 nonfoil en", placed: 1, owned: 0),
      LedgerExcess(identity: "mh2 17 foil en", placed: 3, owned: 2),
    ]
}

fn checkers(
  check_rule: fn(export_document.Rule) -> Result(Nil, String),
  check_sort_keys: fn(String) -> Result(Nil, String),
) -> import_document.DeepCheckers {
  import_document.DeepCheckers(
    check_rule:,
    check_sort_keys:,
    check_managed_kind: fn(_) { Ok(Nil) },
  )
}

pub fn resolve_deep_sections_validates_rules_and_bulk_and_merges_rejections_test() {
  let document =
    ImportDocument(
      ..empty_document(),
      rules: Some([a_rule("Binder A")]),
      bulk: Some(BulkSpec(location: "Bulk", sort_keys: "nope")),
    )

  let resolved =
    import_document.resolve_deep_sections(
      document,
      checkers(fn(_) { Ok(Nil) }, fn(_) { Error("invalid sort keys") }),
    )

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
      managed_locations: None,
      members: None,
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

// --- Managed locations (#122) ---------------------------------------------

fn mh2_17() -> copy_key.CopyKey {
  let assert Ok(key) =
    copy_key.new(
      set_code: "mh2",
      collector_number: "17",
      finish: "foil",
      language: "en",
    )
  key
}

pub fn a_blank_or_repeated_managed_location_name_is_rejected_test() {
  let #(valid, rejected) =
    import_document.validate_managed_locations([
      RawManagedLocation(name: " Burn ", kind: "deck"),
      RawManagedLocation(name: "", kind: "deck"),
      RawManagedLocation(name: "Burn", kind: "deck"),
    ])

  assert valid == [ManagedLocationEntry(name: "Burn", kind: "deck")]
  assert rejected
    == [
      RejectedEntry(ManagedLocationsSection, 2, "", "name is blank"),
      RejectedEntry(ManagedLocationsSection, 3, "Burn", "name is used twice"),
    ]
}

pub fn a_member_naming_an_unknown_managed_location_is_rejected_test() {
  let #(valid, rejected) =
    import_document.validate_members(
      [
        RawMember("Burn", "mh2", "17", "foil", "en", 2),
        RawMember("Elves", "mh2", "17", "foil", "en", 1),
      ],
      set.from_list(["Burn"]),
    )

  assert valid
    == [MemberEntry(managed_location: "Burn", key: mh2_17(), quantity: 2)]
  assert rejected
    == [
      RejectedEntry(
        MembersSection,
        2,
        "Elves mh2 17 foil en",
        "no managed location named \"Elves\"",
      ),
    ]
}

pub fn a_placed_entry_names_exactly_one_kind_of_location_test() {
  let raw = fn(location, managed_location) {
    RawPlaced("mh2", "17", "foil", "en", location, managed_location, 1)
  }
  let #(valid, rejected) =
    import_document.validate_placed(
      [
        raw("Box A", ""),
        raw("", "Burn"),
        raw("Box A", "Burn"),
        raw("", "Elves"),
      ],
      set.from_list(["Burn"]),
    )

  assert list_locations(valid)
    == [InLocation("Box A"), InManagedLocation("Burn")]
  assert list_reasons(rejected)
    == [
      "names both a location and a managed location",
      "no managed location named \"Elves\"",
    ]
}

fn list_locations(
  entries: List(export_document.PlacedEntry),
) -> List(export_document.PlacedIn) {
  case entries {
    [] -> []
    [entry, ..rest] -> [entry.location, ..list_locations(rest)]
  }
}

fn list_reasons(rejected: List(import_document.RejectedEntry)) -> List(String) {
  case rejected {
    [] -> []
    [entry, ..rest] -> [entry.reason, ..list_reasons(rest)]
  }
}

// A managed location rejected for its kind takes its members and placed
// entries with it — nothing may be left pointing at a deck that won't exist.
pub fn a_rejected_managed_location_takes_its_dependents_with_it_test() {
  let document =
    ImportDocument(
      ..empty_document(),
      managed_locations: Some([
        ManagedLocationEntry(name: "Burn", kind: "deck"),
        ManagedLocationEntry(name: "Box", kind: "binder"),
      ]),
      members: Some([
        MemberEntry(managed_location: "Box", key: mh2_17(), quantity: 1),
        MemberEntry(managed_location: "Burn", key: mh2_17(), quantity: 1),
      ]),
      placed: Some([
        PlacedEntry(
          key: mh2_17(),
          location: InManagedLocation("Box"),
          quantity: 1,
        ),
      ]),
    )
  let checkers =
    import_document.DeepCheckers(
      check_rule: fn(_) { Ok(Nil) },
      check_sort_keys: fn(_) { Ok(Nil) },
      check_managed_kind: fn(kind) {
        case kind {
          "deck" -> Ok(Nil)
          _ -> Error("unknown kind")
        }
      },
    )

  let resolved = import_document.resolve_deep_sections(document, checkers)

  assert resolved.managed_locations
    == Some([ManagedLocationEntry(name: "Burn", kind: "deck")])
  assert resolved.members
    == Some([MemberEntry(managed_location: "Burn", key: mh2_17(), quantity: 1)])
  assert resolved.placed == Some([])
  assert list_reasons(resolved.rejected)
    == [
      "unknown kind",
      "its managed location \"Box\" was rejected",
      "its managed location \"Box\" was rejected",
    ]
}

// Precedence matches the projection's: the scarce copy goes to the deck
// whose name sorts first, so the later one is predicted short.
pub fn managed_shortfall_predicts_which_deck_comes_up_short_test() {
  let shortfall =
    import_document.managed_shortfall(
      [CollectionEntry(key: mh2_17(), quantity: 1)],
      [
        ManagedLocationEntry(name: "Burn", kind: "deck"),
        ManagedLocationEntry(name: "Aggro", kind: "deck"),
      ],
      [
        MemberEntry(managed_location: "Burn", key: mh2_17(), quantity: 1),
        MemberEntry(managed_location: "Aggro", key: mh2_17(), quantity: 1),
      ],
    )

  assert shortfall
    == [
      ManagedShortfall(
        location_name: "Burn",
        identity: "mh2 17 foil en",
        missing: 1,
      ),
    ]
}
