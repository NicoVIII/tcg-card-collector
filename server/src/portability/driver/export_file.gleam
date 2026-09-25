import gleam/int
import gleam/json
import gleam/list
import gleam/string
import gleam/time/calendar.{type Date}
import portability/domain/export_document.{type ExportDocument}
import shared/domain/copy_key

/// The one encoder both doors call, so REST and Skir agree byte for byte
/// (ADR 0004). One entry per line, all values passed through `gleam_json`'s
/// string encoding for escaping — only the surrounding layout is hand-built,
/// so the file stays hand-editable (ADR 0019).
pub fn render(document: ExportDocument) -> String {
  let entries =
    document.collection
    |> list.map(encode_entry_line)
    |> join_entries

  "{\n"
  <> "  \"format\": \"tcg-card-collector\",\n"
  <> "  \"format_version\": "
  <> int.to_string(export_document.format_version)
  <> ",\n"
  <> "  \"exported_on\": \""
  <> iso_date(document.exported_on)
  <> "\",\n"
  <> "  \"collection\": "
  <> entries
  <> "\n}\n"
}

pub fn filename(document: ExportDocument) -> String {
  "tcg-card-collector-" <> iso_date(document.exported_on) <> ".json"
}

fn join_entries(lines: List(String)) -> String {
  case lines {
    [] -> "[]"
    _ -> "[\n" <> string.join(lines, ",\n") <> "\n  ]"
  }
}

fn encode_entry_line(entry: export_document.CollectionEntry) -> String {
  "    "
  <> json.to_string(
    json.object([
      #("set_code", json.string(copy_key.set_code_string(entry.key))),
      #(
        "collector_number",
        json.string(copy_key.collector_number_string(entry.key)),
      ),
      #("quantity", json.int(entry.quantity)),
      #("finish", json.string(copy_key.finish_string(entry.key))),
      #("language", json.string(copy_key.language_string(entry.key))),
    ]),
  )
}

fn iso_date(date: Date) -> String {
  int.to_string(date.year)
  <> "-"
  <> string.pad_start(
    int.to_string(calendar.month_to_int(date.month)),
    to: 2,
    with: "0",
  )
  <> "-"
  <> string.pad_start(int.to_string(date.day), to: 2, with: "0")
}
