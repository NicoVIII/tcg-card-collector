import card_catalog/infrastructure/clients/scryfall_client.{type Downloader}
import gleam/dict.{type Dict}
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import shared/infrastructure/shell

// The fallback source for official set sizes only (ADR 0025).
const set_list_url = "https://mtgjson.com/api/v5/SetList.json"

fn log(message: String) -> Nil {
  io.println("[refresh] " <> message)
}

// Prefixes every failure with the source, so a failed refresh names MTGJSON
// rather than reading as a Scryfall problem.
fn or_fail(outcome: Result(a, String), stage: String) -> Result(a, String) {
  result.map_error(outcome, fn(reason) {
    let simplified = shell.simplify_error(reason)
    io.println("[refresh][error] mtgjson " <> stage <> ": " <> simplified)
    "mtgjson " <> stage <> ": " <> simplified
  })
}

// A null or absent baseSetSize is skipped as unknown; any other non-number,
// or a set without a code, fails in jq with a reason naming the field.
const extract_script = "jq -r '.data[] | if (.baseSetSize == null) then empty elif (.code | type) == \"string\" and (.code != \"\") and (.baseSetSize | type) == \"number\" then [(.code | ascii_downcase), (.baseSetSize | tostring)] | @tsv else error(\"invalid code or baseSetSize: \\(.code)\") end' < "

fn parse_line(line: String) -> Result(#(String, Int), String) {
  case string.split(line, "\t") {
    [code, raw_size] ->
      int.parse(raw_size)
      |> result.map(fn(size) { #(code, size) })
      |> result.replace_error("invalid baseSetSize for " <> code)
    _ -> Error("unexpected jq output: " <> line)
  }
}

fn parse_sizes(output: String) -> Result(Dict(String, Int), String) {
  output
  |> string.split("\n")
  |> list.filter(fn(line) { line != "" })
  |> list.try_map(parse_line)
  |> result.map(dict.from_list)
}

/// Downloads MTGJSON's SetList and returns `baseSetSize` per lowercased set
/// code. Sizes of 0 are kept as delivered; `official_size.resolve` reads 0 as
/// unknown.
pub fn fetch_base_set_sizes(
  io: Downloader,
) -> Result(Dict(String, Int), String) {
  use path <- result.try(io.download(set_list_url) |> or_fail("download"))
  use output <- result.try(
    shell.run(extract_script <> shell.quote(path)) |> or_fail("jq parse"),
  )
  use sizes <- result.try(parse_sizes(output) |> or_fail("parse"))
  log("mtgjson ok: " <> int.to_string(dict.size(sizes)) <> " set sizes")
  Ok(sizes)
}
