import gleam/time/calendar
import portability/domain/export_document.{CollectionEntry, ExportDocument}
import portability/domain/import_document.{
  MissingCollection, NotJson, NotThisFormat, RejectedEntry, UnsupportedVersion,
}
import portability/driver/export_file
import shared/domain/copy_key

fn a_date() -> calendar.Date {
  calendar.Date(2026, calendar.September, 25)
}

pub fn filename_is_dated_from_the_document_test() {
  let document = ExportDocument(exported_on: a_date(), collection: [])

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
    ExportDocument(exported_on: a_date(), collection: [
      CollectionEntry(key: nonfoil_en, quantity: 1),
      CollectionEntry(key: foil_en, quantity: 2),
      CollectionEntry(key: etched_zhs, quantity: 3),
    ])

  assert export_file.render(document)
    == "{\n"
    <> "  \"format\": \"tcg-card-collector\",\n"
    <> "  \"format_version\": 1,\n"
    <> "  \"exported_on\": \"2026-09-25\",\n"
    <> "  \"collection\": [\n"
    <> "    {\"set_code\":\"dmu\",\"collector_number\":\"2\",\"quantity\":1,\"finish\":\"nonfoil\",\"language\":\"en\"},\n"
    <> "    {\"set_code\":\"dmu\",\"collector_number\":\"101\",\"quantity\":2,\"finish\":\"foil\",\"language\":\"en\"},\n"
    <> "    {\"set_code\":\"dmu\",\"collector_number\":\"101\",\"quantity\":3,\"finish\":\"etched\",\"language\":\"zhs\"}\n"
    <> "  ]\n"
    <> "}\n"
}

pub fn an_empty_collection_renders_as_an_empty_array_test() {
  let document = ExportDocument(exported_on: a_date(), collection: [])

  assert export_file.render(document)
    == "{\n"
    <> "  \"format\": \"tcg-card-collector\",\n"
    <> "  \"format_version\": 1,\n"
    <> "  \"exported_on\": \"2026-09-25\",\n"
    <> "  \"collection\": []\n"
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
    ExportDocument(exported_on: a_date(), collection: [
      CollectionEntry(key: nonfoil_en, quantity: 1),
      CollectionEntry(key: etched_zhs, quantity: 3),
      CollectionEntry(key: foil_zht, quantity: 2),
    ])
  let rendered = export_file.render(original)

  let assert Ok(parsed) = export_file.parse(rendered)
  assert parsed.rejected == []
  let re_rendered =
    export_file.render(ExportDocument(
      exported_on: a_date(),
      collection: parsed.collection,
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
      "{\"format\": \"tcg-card-collector\", \"format_version\": 1, \"collection\": [], \"insights\": {}}",
    )

  assert document.collection == []
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
        position: 1,
        identity: "mh2 17 foill en",
        reason: "unknown finish",
      ),
    ]
}
