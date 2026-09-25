import gleam/option.{None, Some}
import gleam/time/calendar
import portability/domain/export_document.{
  type InsightsSection, type InventoryPlanningSection, BulkSpec, CollectionEntry,
  ExportDocument, InsightsSection, InventoryPlanningSection, PlacedEntry, Rule,
}
import portability/domain/import_document.{
  CollectionSection, MissingCollection, NotJson, NotThisFormat, PlacedSection,
  RejectedEntry, TargetSetsSection, UnsupportedVersion,
}
import portability/driver/export_file
import shared/domain/copy_key

fn a_date() -> calendar.Date {
  calendar.Date(2026, calendar.September, 25)
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

pub fn filename_is_dated_from_the_document_test() {
  let document =
    ExportDocument(
      exported_on: a_date(),
      collection: [],
      insights: no_targets(),
      inventory_planning: no_plan(),
    )

  assert export_file.filename(document) == "tcg-card-collector-2026-09-25.json"
}

pub fn renders_every_finish_and_a_non_english_language_by_enum_name_test() {
  let assert Ok(nonfoil_en) =
    copy_key.new(
      set_code: "dmu",
      collector_number: "2",
      finish: "nonfoil",
      language: "en",
    )
  let assert Ok(foil_en) =
    copy_key.new(
      set_code: "dmu",
      collector_number: "101",
      finish: "foil",
      language: "en",
    )
  let assert Ok(etched_zhs) =
    copy_key.new(
      set_code: "dmu",
      collector_number: "101",
      finish: "etched",
      language: "zhs",
    )
  let document =
    ExportDocument(
      exported_on: a_date(),
      collection: [
        CollectionEntry(key: nonfoil_en, quantity: 1),
        CollectionEntry(key: foil_en, quantity: 2),
        CollectionEntry(key: etched_zhs, quantity: 3),
      ],
      insights: InsightsSection(target_sets: ["2xm", "neo"]),
      inventory_planning: no_plan(),
    )

  assert export_file.render(document)
    == "{\n"
    <> "  \"format\": \"tcg-card-collector\",\n"
    <> "  \"format_version\": 1,\n"
    <> "  \"exported_on\": \"2026-09-25\",\n"
    <> "  \"collection\": [\n"
    <> "    {\"set_code\":\"dmu\",\"collector_number\":\"2\",\"quantity\":1,\"finish\":\"nonfoil\",\"language\":\"en\"},\n"
    <> "    {\"set_code\":\"dmu\",\"collector_number\":\"101\",\"quantity\":2,\"finish\":\"foil\",\"language\":\"en\"},\n"
    <> "    {\"set_code\":\"dmu\",\"collector_number\":\"101\",\"quantity\":3,\"finish\":\"etched\",\"language\":\"zhs\"}\n"
    <> "  ],\n"
    <> "  \"inventory_planning\": {\n"
    <> "    \"rules\": [],\n"
    <> "    \"bulk\": {\"location\":\"Bulk\",\"sort\":\"\"},\n"
    <> "    \"placed\": []\n"
    <> "  },\n"
    <> "  \"insights\": {\n"
    <> "    \"target_sets\": [\"2xm\",\"neo\"]\n"
    <> "  }\n"
    <> "}\n"
}

pub fn an_empty_collection_renders_as_an_empty_array_test() {
  let document =
    ExportDocument(
      exported_on: a_date(),
      collection: [],
      insights: no_targets(),
      inventory_planning: no_plan(),
    )

  assert export_file.render(document)
    == "{\n"
    <> "  \"format\": \"tcg-card-collector\",\n"
    <> "  \"format_version\": 1,\n"
    <> "  \"exported_on\": \"2026-09-25\",\n"
    <> "  \"collection\": [],\n"
    <> "  \"inventory_planning\": {\n"
    <> "    \"rules\": [],\n"
    <> "    \"bulk\": {\"location\":\"Bulk\",\"sort\":\"\"},\n"
    <> "    \"placed\": []\n"
    <> "  },\n"
    <> "  \"insights\": {\n"
    <> "    \"target_sets\": []\n"
    <> "  }\n"
    <> "}\n"
}

pub fn renders_rules_bulk_and_placed_nested_under_inventory_planning_test() {
  let assert Ok(mh2_key) =
    copy_key.new(
      set_code: "mh2",
      collector_number: "17",
      finish: "foil",
      language: "en",
    )
  let document =
    ExportDocument(
      exported_on: a_date(),
      collection: [],
      insights: no_targets(),
      inventory_planning: InventoryPlanningSection(
        rules: [
          Rule(
            location: "Binder {set_code}",
            expression: "rarity >= rare",
            selector: "all",
            sort_keys: "collector_number",
          ),
        ],
        bulk: BulkSpec(location: "Bulk", sort_keys: "color_identity,type,name"),
        placed: [
          PlacedEntry(key: mh2_key, location: "Binder mh2", quantity: 1),
        ],
      ),
    )

  assert export_file.render(document)
    == "{\n"
    <> "  \"format\": \"tcg-card-collector\",\n"
    <> "  \"format_version\": 1,\n"
    <> "  \"exported_on\": \"2026-09-25\",\n"
    <> "  \"collection\": [],\n"
    <> "  \"inventory_planning\": {\n"
    <> "    \"rules\": [\n"
    <> "      {\"location\":\"Binder {set_code}\",\"match\":\"rarity >= rare\",\"copies\":\"all\",\"sort\":\"collector_number\"}\n"
    <> "    ],\n"
    <> "    \"bulk\": {\"location\":\"Bulk\",\"sort\":\"color_identity,type,name\"},\n"
    <> "    \"placed\": [\n"
    <> "      {\"set_code\":\"mh2\",\"collector_number\":\"17\",\"finish\":\"foil\",\"language\":\"en\",\"location\":\"Binder mh2\",\"quantity\":1}\n"
    <> "    ]\n"
    <> "  },\n"
    <> "  \"insights\": {\n"
    <> "    \"target_sets\": []\n"
    <> "  }\n"
    <> "}\n"
}

pub fn render_then_parse_then_render_is_byte_identical_including_etched_and_the_chinese_split_test() {
  let assert Ok(nonfoil_en) =
    copy_key.new(
      set_code: "dmu",
      collector_number: "2",
      finish: "nonfoil",
      language: "en",
    )
  let assert Ok(etched_zhs) =
    copy_key.new(
      set_code: "dmu",
      collector_number: "101",
      finish: "etched",
      language: "zhs",
    )
  let assert Ok(foil_zht) =
    copy_key.new(
      set_code: "mh2",
      collector_number: "17",
      finish: "foil",
      language: "zht",
    )
  let original =
    ExportDocument(
      exported_on: a_date(),
      collection: [
        CollectionEntry(key: nonfoil_en, quantity: 1),
        CollectionEntry(key: etched_zhs, quantity: 3),
        CollectionEntry(key: foil_zht, quantity: 2),
      ],
      insights: InsightsSection(target_sets: ["neo", "2xm"]),
      inventory_planning: InventoryPlanningSection(
        rules: [
          Rule(
            location: "Binder A",
            expression: "rarity >= mythic",
            selector: "all",
            sort_keys: "",
          ),
        ],
        bulk: BulkSpec(location: "Bulk", sort_keys: "color_identity"),
        placed: [
          PlacedEntry(key: foil_zht, location: "Binder A", quantity: 2),
        ],
      ),
    )
  let rendered = export_file.render(original)

  let assert Ok(parsed) = export_file.parse(rendered)
  assert parsed.rejected == []
  let assert Some(target_sets) = parsed.target_sets
  let assert Some(rules) = parsed.rules
  let assert Some(bulk) = parsed.bulk
  let assert Some(placed) = parsed.placed
  let re_rendered =
    export_file.render(ExportDocument(
      exported_on: a_date(),
      collection: parsed.collection,
      insights: InsightsSection(target_sets:),
      inventory_planning: InventoryPlanningSection(rules:, bulk:, placed:),
    ))

  assert re_rendered == rendered
}

pub fn non_json_content_is_rejected_test() {
  assert export_file.parse("not json at all") == Error(NotJson)
}

pub fn a_missing_or_wrong_format_marker_is_rejected_test() {
  assert export_file.parse(
      "{\"format\": \"something-else\", \"format_version\": 1, \"collection\": []}",
    )
    == Error(NotThisFormat)
  assert export_file.parse("{\"format_version\": 1, \"collection\": []}")
    == Error(NotThisFormat)
}

pub fn an_unsupported_format_version_is_rejected_before_any_entry_is_parsed_test() {
  assert export_file.parse(
      "{\"format\": \"tcg-card-collector\", \"format_version\": 2, \"collection\": [{}]}",
    )
    == Error(UnsupportedVersion("2"))
}

pub fn a_missing_format_version_is_rejected_as_unsupported_test() {
  assert export_file.parse(
      "{\"format\": \"tcg-card-collector\", \"collection\": []}",
    )
    == Error(UnsupportedVersion("missing"))
}

pub fn a_missing_collection_section_is_rejected_test() {
  assert export_file.parse(
      "{\"format\": \"tcg-card-collector\", \"format_version\": 1}",
    )
    == Error(MissingCollection)
}

pub fn an_unknown_top_level_key_is_tolerated_test() {
  let assert Ok(document) =
    export_file.parse(
      "{\"format\": \"tcg-card-collector\", \"format_version\": 1, \"collection\": [], \"some_future_key\": {}}",
    )

  assert document.collection == []
  assert document.target_sets == None
  assert document.rules == None
  assert document.bulk == None
  assert document.placed == None
}

pub fn one_bad_entry_is_rejected_at_its_position_while_the_rest_parse_test() {
  let assert Ok(document) =
    export_file.parse(
      "{\"format\": \"tcg-card-collector\", \"format_version\": 1, \"collection\": ["
      <> "{\"set_code\":\"mh2\",\"collector_number\":\"17\",\"quantity\":2,\"finish\":\"foill\",\"language\":\"en\"},"
      <> "{\"set_code\":\"dmu\",\"collector_number\":\"101\",\"quantity\":3,\"finish\":\"etched\",\"language\":\"zhs\"}"
      <> "]}",
    )

  let assert Ok(dmu_key) =
    copy_key.new(
      set_code: "dmu",
      collector_number: "101",
      finish: "etched",
      language: "zhs",
    )
  assert document.collection == [CollectionEntry(key: dmu_key, quantity: 3)]
  assert document.rejected
    == [
      RejectedEntry(
        section: CollectionSection,
        position: 1,
        identity: "mh2 17 foill en",
        reason: "unknown finish",
      ),
    ]
}

pub fn insights_section_absent_from_the_file_parses_as_none_test() {
  let assert Ok(document) =
    export_file.parse(
      "{\"format\": \"tcg-card-collector\", \"format_version\": 1, \"collection\": []}",
    )

  assert document.target_sets == None
}

pub fn insights_target_sets_present_but_empty_parses_as_some_empty_list_test() {
  let assert Ok(document) =
    export_file.parse(
      "{\"format\": \"tcg-card-collector\", \"format_version\": 1, \"collection\": [], \"insights\": {\"target_sets\": []}}",
    )

  assert document.target_sets == Some([])
}

pub fn a_blank_target_set_code_is_rejected_at_its_position_while_the_rest_parse_test() {
  let assert Ok(document) =
    export_file.parse(
      "{\"format\": \"tcg-card-collector\", \"format_version\": 1, \"collection\": [], "
      <> "\"insights\": {\"target_sets\": [\"neo\", \"  \"]}}",
    )

  assert document.target_sets == Some(["neo"])
  assert document.rejected
    == [
      RejectedEntry(
        section: TargetSetsSection,
        position: 2,
        identity: "  ",
        reason: "set code is blank",
      ),
    ]
}

pub fn rules_are_decoded_structurally_without_dsl_validation_test() {
  let assert Ok(document) =
    export_file.parse(
      "{\"format\": \"tcg-card-collector\", \"format_version\": 1, \"collection\": [], "
      <> "\"inventory_planning\": {\"rules\": [{\"location\": \"Binder A\", \"match\": \"not a real predicate\", \"sort\": \"\"}]}}",
    )

  // "not a real predicate" would fail Inventory Planning's parser, but
  // export_file.parse never calls it — that's the application layer's job.
  assert document.rules
    == Some([
      Rule(
        location: "Binder A",
        expression: "not a real predicate",
        selector: "all",
        sort_keys: "",
      ),
    ])
  assert document.rejected == []
}

pub fn rules_section_absent_from_the_file_parses_as_none_test() {
  let assert Ok(document) =
    export_file.parse(
      "{\"format\": \"tcg-card-collector\", \"format_version\": 1, \"collection\": []}",
    )

  assert document.rules == None
}

pub fn bulk_is_decoded_structurally_test() {
  let assert Ok(document) =
    export_file.parse(
      "{\"format\": \"tcg-card-collector\", \"format_version\": 1, \"collection\": [], "
      <> "\"inventory_planning\": {\"bulk\": {\"location\": \"Bulk\", \"sort\": \"name\"}}}",
    )

  assert document.bulk == Some(BulkSpec(location: "Bulk", sort_keys: "name"))
}

pub fn bulk_absent_from_the_file_parses_as_none_test() {
  let assert Ok(document) =
    export_file.parse(
      "{\"format\": \"tcg-card-collector\", \"format_version\": 1, \"collection\": []}",
    )

  assert document.bulk == None
}

pub fn placed_entries_are_fully_validated_because_they_need_no_other_context_test() {
  let assert Ok(mh2_key) =
    copy_key.new(
      set_code: "mh2",
      collector_number: "17",
      finish: "foil",
      language: "en",
    )
  let assert Ok(document) =
    export_file.parse(
      "{\"format\": \"tcg-card-collector\", \"format_version\": 1, \"collection\": [], "
      <> "\"inventory_planning\": {\"placed\": ["
      <> "{\"set_code\": \"mh2\", \"collector_number\": \"17\", \"finish\": \"foil\", \"language\": \"en\", \"location\": \"Box A\", \"quantity\": 2},"
      <> "{\"set_code\": \"mh2\", \"collector_number\": \"17\", \"finish\": \"foill\", \"language\": \"en\", \"location\": \"Box A\", \"quantity\": 1}"
      <> "]}}",
    )

  assert document.placed
    == Some([PlacedEntry(key: mh2_key, location: "Box A", quantity: 2)])
  assert document.rejected
    == [
      RejectedEntry(
        section: PlacedSection,
        position: 2,
        identity: "mh2 17 foill en Box A",
        reason: "unknown finish",
      ),
    ]
}

pub fn placed_absent_from_the_file_parses_as_none_test() {
  let assert Ok(document) =
    export_file.parse(
      "{\"format\": \"tcg-card-collector\", \"format_version\": 1, \"collection\": []}",
    )

  assert document.placed == None
}
