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
import portability/domain/export_document.{
  type BulkSpec, type ExportDocument, type PlacedEntry, type Rule,
}
import portability/domain/import_document.{
  type DocumentError, type ImportDocument, type RawEntry, type RawPlaced,
  MissingCollection, NotJson, NotThisFormat, RawEntry, RawPlaced,
  UnsupportedVersion,
}
import shared/domain/copy_key

/// The one encoder both doors call, so REST and Skir agree byte for byte
/// (ADR 0004). One entry per line, all values passed through `gleam_json`'s
/// string encoding for escaping — only the surrounding layout is hand-built,
/// so the file stays hand-editable (ADR 0019). Rule/bulk field names are
/// Portability's own vocabulary (`match`, `copies`, `sort`), not the DB
/// column names — the DSL text itself round-trips through Inventory
/// Planning's own parser/printer, never re-interpreted here.
pub fn render(document: ExportDocument) -> String {
  let entries =
    document.collection
    |> list.map(fn(entry) { encode_entry_line("    ", entry) })
    |> join_entries("  ")
  let rules =
    document.inventory_planning.rules
    |> list.map(fn(rule) { encode_rule_line("      ", rule) })
    |> join_entries("    ")
  let placed =
    document.inventory_planning.placed
    |> list.map(fn(entry) { encode_placed_line("      ", entry) })
    |> join_entries("    ")

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
  <> "  \"inventory_planning\": {\n"
  <> "    \"rules\": "
  <> rules
  <> ",\n"
  <> "    \"bulk\": "
  <> encode_bulk(document.inventory_planning.bulk)
  <> ",\n"
  <> "    \"placed\": "
  <> placed
  <> "\n"
  <> "  },\n"
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
/// reported per-entry, so the rest of the file still imports. Unknown
/// top-level and per-entry keys are silently ignored — ADR 0019 tolerates
/// them by design.
///
/// Rules and the bulk spec are only decoded structurally here — their DSL
/// fields (match/copies/sort) aren't validated, because that needs
/// Inventory Planning's own parsers, which this driver-layer function has
/// no port to reach. The application layer's import_data/preview_import
/// handlers run that second validation pass through an injected
/// check_rule/check_sort_keys port before anything is written or shown.
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
  let #(placed, placed_rejected) = parse_placed(root)
  Ok(import_document.ImportDocument(
    collection: entries,
    rejected: list.flatten([
      collection_rejected,
      target_sets_rejected,
      placed_rejected,
    ]),
    target_sets:,
    rules: parse_rules(root),
    bulk: parse_bulk(root),
    placed:,
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

/// Absent when the file has no "inventory_planning.rules" array. Every
/// field decoded here still needs Inventory Planning's DSL validation
/// (see `parse`'s doc comment) — `copies` alone defaults to "all" when
/// omitted, since that is the one field a hand-written rule can reasonably
/// leave out and still mean something.
fn parse_rules(root: Dynamic) -> Option(List(Rule)) {
  case
    decode.run(
      root,
      decode.at(["inventory_planning", "rules"], decode.list(decode.dynamic)),
    )
  {
    Ok(items) -> Some(list.map(items, raw_rule))
    Error(_) -> None
  }
}

fn raw_rule(item: Dynamic) -> Rule {
  export_document.Rule(
    location: optional_string(item, "location"),
    expression: optional_string(item, "match"),
    selector: optional_string_default(item, "copies", "all"),
    sort_keys: optional_string(item, "sort"),
  )
}

/// Absent when the file has no "inventory_planning.bulk" object.
fn parse_bulk(root: Dynamic) -> Option(BulkSpec) {
  case
    decode.run(root, decode.at(["inventory_planning", "bulk"], decode.dynamic))
  {
    Ok(item) ->
      Some(export_document.BulkSpec(
        location: optional_string(item, "location"),
        sort_keys: optional_string(item, "sort"),
      ))
    Error(_) -> None
  }
}

/// Absent when the file has no "inventory_planning.placed" array. Unlike
/// rules/bulk, a placed entry's identity and location need no other
/// context's parser, so it is fully validated here, same as `collection`.
fn parse_placed(
  root: Dynamic,
) -> #(Option(List(PlacedEntry)), List(import_document.RejectedEntry)) {
  case
    decode.run(
      root,
      decode.at(["inventory_planning", "placed"], decode.list(decode.dynamic)),
    )
  {
    Ok(items) -> {
      let #(entries, rejected) =
        items
        |> list.map(raw_placed)
        |> import_document.validate_placed
      #(Some(entries), rejected)
    }
    Error(_) -> #(None, [])
  }
}

fn raw_placed(item: Dynamic) -> RawPlaced {
  RawPlaced(
    set_code: optional_string(item, "set_code"),
    collector_number: optional_string(item, "collector_number"),
    finish: optional_string(item, "finish"),
    language: optional_string(item, "language"),
    location: optional_string(item, "location"),
    quantity: optional_int(item, "quantity"),
  )
}

fn join_entries(lines: List(String), close_indent: String) -> String {
  case lines {
    [] -> "[]"
    _ -> "[\n" <> string.join(lines, ",\n") <> "\n" <> close_indent <> "]"
  }
}

fn encode_entry_line(
  indent: String,
  entry: export_document.CollectionEntry,
) -> String {
  indent
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

fn encode_rule_line(indent: String, rule: Rule) -> String {
  indent
  <> json.to_string(
    json.object([
      #("location", json.string(rule.location)),
      #("match", json.string(rule.expression)),
      #("copies", json.string(rule.selector)),
      #("sort", json.string(rule.sort_keys)),
    ]),
  )
}

fn encode_bulk(spec: BulkSpec) -> String {
  json.to_string(
    json.object([
      #("location", json.string(spec.location)),
      #("sort", json.string(spec.sort_keys)),
    ]),
  )
}

fn encode_placed_line(indent: String, entry: PlacedEntry) -> String {
  indent
  <> json.to_string(
    json.object([
      #("set_code", json.string(copy_key.set_code_string(entry.key))),
      #(
        "collector_number",
        json.string(copy_key.collector_number_string(entry.key)),
      ),
      #("finish", json.string(copy_key.finish_string(entry.key))),
      #("language", json.string(copy_key.language_string(entry.key))),
      #("location", json.string(entry.location)),
      #("quantity", json.int(entry.quantity)),
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
  optional_string_default(item, key, "")
}

fn optional_string_default(
  item: Dynamic,
  key: String,
  default: String,
) -> String {
  case decode.run(item, decode.at([key], decode.string)) {
    Ok(value) -> value
    Error(_) -> default
  }
}

fn optional_int(item: Dynamic, key: String) -> Int {
  case decode.run(item, decode.at([key], decode.int)) {
    Ok(value) -> value
    Error(_) -> 0
  }
}
