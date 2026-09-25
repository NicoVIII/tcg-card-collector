import gleam/bool
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/time/calendar.{type Date}
import portability/domain/export_document.{type ExportDocument}
import portability/domain/import_document.{
  type DocumentError, type ImportDocument, type RawEntry, MissingCollection,
  NotJson, NotThisFormat, RawEntry, UnsupportedVersion,
}
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
  <> ",\n"
  <> "  \"insights\": {\n"
  <> "    \"target_sets\": "
  <> json.to_string(json.array(document.insights.target_sets, of: json.string))
  <> "\n  }\n"
  <> "}\n"
}

pub fn filename(document: ExportDocument) -> String {
  "tcg-card-collector-" <> iso_date(document.exported_on) <> ".json"
}

/// The decoder side of `render`, so the one file format has one encoder and
/// one decoder. Whole-file problems (bad JSON, wrong `format`, an
/// unsupported `format_version`, a missing `collection`) are checked in
/// that order before any entry is parsed (ADR 0019); a bad entry is instead
/// reported per-entry by `validate_entries`, so the rest of the file still
/// imports. Unknown top-level and per-entry keys are silently ignored —
/// ADR 0019 tolerates them by design.
pub fn parse(content: String) -> Result(ImportDocument, DocumentError) {
  use root <- result.try(
    json.parse(from: content, using: decode.dynamic)
    |> result.replace_error(NotJson),
  )
  use <- bool.guard(
    decode.run(root, decode.at(["format"], decode.string))
      != Ok("tcg-card-collector"),
    Error(NotThisFormat),
  )
  use _ <- result.try(check_version(root))
  use items <- result.try(
    decode.run(root, decode.at(["collection"], decode.list(decode.dynamic)))
    |> result.replace_error(MissingCollection),
  )
  let #(entries, collection_rejected) =
    items
    |> list.map(raw_entry)
    |> import_document.validate_entries
  let #(target_sets, target_sets_rejected) = parse_target_sets(root)
  Ok(import_document.ImportDocument(
    collection: entries,
    rejected: list.append(collection_rejected, target_sets_rejected),
    target_sets:,
  ))
}

/// Absent when the file has no "insights.target_sets" array — an older
/// export, or a malformed section, is treated the same as absent rather
/// than failing the whole file (ADR 0019: unrecognised or malformed
/// top-level shape is tolerated, only the checked whole-file problems
/// reject the document).
fn parse_target_sets(
  root: Dynamic,
) -> #(Option(List(String)), List(import_document.RejectedEntry)) {
  case
    decode.run(
      root,
      decode.at(["insights", "target_sets"], decode.list(decode.string)),
    )
  {
    Ok(raw) -> {
      let #(codes, rejected) = import_document.validate_target_sets(raw)
      #(Some(codes), rejected)
    }
    Error(_) -> #(None, [])
  }
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

fn check_version(root: Dynamic) -> Result(Nil, DocumentError) {
  case decode.run(root, decode.at(["format_version"], decode.int)) {
    Ok(version) if version == export_document.format_version -> Ok(Nil)
    Ok(other) -> Error(UnsupportedVersion(int.to_string(other)))
    Error(_) -> Error(UnsupportedVersion("missing"))
  }
}

/// Every field defaults rather than fails the whole entry, so a malformed
/// one is still reported with whatever identity it carried — validation
/// (and the resulting rejection reason) is `validate_entries`' job.
fn raw_entry(item: Dynamic) -> RawEntry {
  RawEntry(
    set_code: optional_string(item, "set_code"),
    collector_number: optional_string(item, "collector_number"),
    quantity: optional_int(item, "quantity"),
    finish: optional_string(item, "finish"),
    language: optional_string(item, "language"),
  )
}

fn optional_string(item: Dynamic, key: String) -> String {
  case decode.run(item, decode.at([key], decode.string)) {
    Ok(value) -> value
    Error(_) -> ""
  }
}

fn optional_int(item: Dynamic, key: String) -> Int {
  case decode.run(item, decode.at([key], decode.int)) {
    Ok(value) -> value
    Error(_) -> 0
  }
}
