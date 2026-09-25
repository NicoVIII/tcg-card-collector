import gleam/time/calendar
import portability/domain/export_document.{CollectionEntry, ExportDocument}
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
