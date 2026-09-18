import card_catalog/domain/card_printing
import card_catalog/domain/card_set
import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None}
import gleam/result
import gleam/string
import shared/domain/card_key
import shared/domain/color_identity
import shared/domain/mana_value
import shared/domain/non_empty_string
import shared/domain/oracle_id
import shared/domain/rarity
import shared/domain/release_date
import shared/infrastructure/shell
import simplifile

fn log(message: String) -> Nil {
  io.println("[refresh] " <> message)
}

fn log_warn(detail: String) -> Nil {
  io.println("[refresh][warn] " <> detail)
}

fn log_error(stage: String, detail: String) -> Nil {
  io.println("[refresh][error] " <> stage <> ": " <> detail)
}

// Absent enrichment values (reversible/multi-face layouts) become None; a
// present-but-unparseable value is a source defect and rejects the row
// (ADR 0008). An oracle id has no shape to violate beyond emptiness, so it
// can't be malformed — only absent.
fn parse_optional_oracle_id(raw: String) -> Option(oracle_id.OracleId) {
  option.from_result(oracle_id.new(raw))
}

fn parse_optional_release_date(
  raw: String,
) -> Result(Option(release_date.ReleaseDate), Nil) {
  case string.trim(raw) {
    "" -> Ok(None)
    trimmed -> release_date.parse(trimmed) |> result.map(option.Some)
  }
}

fn parse_optional_mana_value(
  raw: String,
) -> Result(Option(mana_value.ManaValue), Nil) {
  case string.trim(raw) {
    "" -> Ok(None)
    trimmed -> mana_value.parse(trimmed) |> result.map(option.Some)
  }
}

type Enrichment {
  Enrichment(
    oracle_id: Option(oracle_id.OracleId),
    color_identity: color_identity.ColorIdentity,
    released_at: Option(release_date.ReleaseDate),
    cmc: Option(mana_value.ManaValue),
  )
}

fn parse_enrichment(
  oracle_id_raw: String,
  color_identity_raw: String,
  released_at_raw: String,
  cmc_raw: String,
) -> Result(Enrichment, String) {
  let oracle = parse_optional_oracle_id(oracle_id_raw)
  // "" is a real colorless identity (Scryfall joins an empty color array),
  // not a gap — hence not Option like the others.
  use colors <- result.try(
    color_identity.parse(color_identity_raw)
    |> result.replace_error("invalid color_identity: " <> color_identity_raw),
  )
  use date <- result.try(
    parse_optional_release_date(released_at_raw)
    |> result.replace_error("invalid released_at: " <> released_at_raw),
  )
  use cmc <- result.try(
    parse_optional_mana_value(cmc_raw)
    |> result.replace_error("invalid cmc: " <> cmc_raw),
  )
  Ok(Enrichment(
    oracle_id: oracle,
    color_identity: colors,
    released_at: date,
    cmc: cmc,
  ))
}

// One line of the jq-normalised ndjson, still in Scryfall's raw spellings.
type RawCardRow {
  RawCardRow(
    id: String,
    name: String,
    set_code: String,
    collector_number: String,
    rarity: String,
    image_uri: String,
    oracle_id: String,
    color_identity: String,
    type_line: String,
    released_at: String,
    cmc: String,
  )
}

fn raw_card_row_decoder() -> decode.Decoder(RawCardRow) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use set_code <- decode.field("set_code", decode.string)
  use collector_number <- decode.field("collector_number", decode.string)
  use rarity <- decode.field("rarity", decode.string)
  use image_uri <- decode.field("image_uri", decode.string)
  use oracle_id <- decode.field("oracle_id", decode.string)
  use color_identity <- decode.field("color_identity", decode.string)
  use type_line <- decode.field("type_line", decode.string)
  use released_at <- decode.field("released_at", decode.string)
  use cmc <- decode.field("cmc", decode.string)
  decode.success(RawCardRow(
    id:,
    name:,
    set_code:,
    collector_number:,
    rarity:,
    image_uri:,
    oracle_id:,
    color_identity:,
    type_line:,
    released_at:,
    cmc:,
  ))
}

fn parse_card_row(line: String) -> Result(card_printing.CardPrinting, String) {
  use raw <- result.try(
    json.parse(from: line, using: raw_card_row_decoder())
    |> result.replace_error(
      "invalid json: " <> string.slice(from: line, at_index: 0, length: 80),
    ),
  )
  let reject = fn(reason: String) { "id=" <> raw.id <> " " <> reason }
  use name <- result.try(
    non_empty_string.new(raw.name) |> result.replace_error(reject("empty name")),
  )
  use key <- result.try(
    card_key.new(set_code: raw.set_code, collector_number: raw.collector_number)
    |> result.map_error(fn(error) { reject(card_key.describe_error(error)) }),
  )
  use rarity_val <- result.try(
    rarity.parse(raw.rarity)
    |> result.replace_error(reject("unknown rarity: " <> raw.rarity)),
  )
  use image_uri <- result.try(
    non_empty_string.new(raw.image_uri)
    |> result.replace_error(reject("empty image_uri")),
  )
  use enrichment <- result.try(
    parse_enrichment(
      raw.oracle_id,
      raw.color_identity,
      raw.released_at,
      raw.cmc,
    )
    |> result.map_error(reject),
  )
  Ok(card_printing.CardPrinting(
    id: card_printing.CardPrintingId(raw.id),
    key:,
    name:,
    rarity: rarity_val,
    image_uri:,
    oracle_id: enrichment.oracle_id,
    color_identity: enrichment.color_identity,
    // The raw printed line is the fact; "" is the multi-face layout gap (see
    // card_printing).
    type_line: raw.type_line,
    released_at: enrichment.released_at,
    cmc: enrichment.cmc,
  ))
}

fn csv_field(value: String) -> String {
  let needs_quoting =
    string.contains(value, ",")
    || string.contains(value, "\"")
    || string.contains(value, "\n")
    || string.contains(value, "\r")
  case needs_quoting {
    False -> value
    True -> "\"" <> string.replace(value, "\"", "\"\"") <> "\""
  }
}

fn card_to_csv_row(card: card_printing.CardPrinting) -> String {
  let card_printing.CardPrinting(
    id: card_printing.CardPrintingId(id),
    key: key,
    name: name,
    rarity: rarity_value,
    image_uri: image_uri,
    oracle_id: oracle,
    color_identity: colors,
    type_line: type_line,
    released_at: date,
    cmc: cmc,
  ) = card
  csv_field(id)
  <> ","
  <> csv_field(non_empty_string.to_string(name))
  <> ","
  <> csv_field(card_key.set_code_string(key))
  <> ","
  <> csv_field(card_key.collector_number_string(key))
  <> ","
  <> csv_field(rarity.to_string(rarity_value))
  <> ","
  <> csv_field(non_empty_string.to_string(image_uri))
  <> ","
  <> csv_field(oracle |> option.map(oracle_id.to_string) |> option.unwrap(""))
  <> ","
  <> csv_field(color_identity.letters(colors))
  <> ","
  <> csv_field(type_line)
  <> ","
  <> csv_field(date |> option.map(release_date.to_string) |> option.unwrap(""))
  <> ","
  <> csv_field(cmc |> option.map(mana_value.to_string) |> option.unwrap(""))
}

fn validate_card_rows(lines: List(String)) -> List(card_printing.CardPrinting) {
  list.filter_map(lines, fn(line) {
    case parse_card_row(line) {
      Ok(card) -> Ok(card)
      Error(reason) -> {
        log_warn("skipped invalid card: " <> reason)
        Error(Nil)
      }
    }
  })
}

fn run_jq(download_path: String, ndjson_path: String) -> Result(Nil, String) {
  // Enrichment fields tolerate multi-face/reversible layouts that expose no
  // top-level value: fall back to the first card face, then to "". color_identity
  // is a WUBRG letter array joined into a canonical-ish string; planning
  // re-canonicalizes at its port boundary. cmc is stringified so the ndjson
  // stays uniformly string-shaped like every other enrichment field (jq's `//`
  // treats 0 as truthy, so a zero-cost card is not swallowed by the fallback).
  // The bulk file is gzipped JSON Lines; gzip -t runs first because sh has no
  // portable pipefail to catch a corrupt archive mid-pipe.
  let jq_script =
    "gzip -t < "
    <> shell.quote(download_path)
    <> " && gzip -dc < "
    <> shell.quote(download_path)
    <> " | jq -c '{id: (.id // \"\"), name: (.name // \"\"), set_code: (.set // \"\"), collector_number: (.collector_number // \"\"), rarity: (.rarity // \"unknown\"), image_uri: (.image_uris.small // .card_faces[0].image_uris.small // \"\"), oracle_id: (.oracle_id // .card_faces[0].oracle_id // \"\"), color_identity: ((.color_identity // []) | join(\"\")), type_line: (.type_line // .card_faces[0].type_line // \"\"), released_at: (.released_at // \"\"), cmc: ((.cmc // .card_faces[0].cmc // \"\") | tostring)}' > "
    <> shell.quote(ndjson_path)
  case shell.run(jq_script) {
    Ok(_) -> {
      log("import: jq->ndjson ok")
      Ok(Nil)
    }
    Error(output) -> {
      let simplified = shell.simplify_error(output)
      log_error("import jq->ndjson", simplified)
      shell.remove_file(ndjson_path)
      Error(simplified)
    }
  }
}

// The ndjson is consumed into memory here, so it is removed on both outcomes.
fn read_ndjson(ndjson_path: String) -> Result(String, String) {
  let contents = simplifile.read(ndjson_path)
  shell.remove_file(ndjson_path)
  case contents {
    Ok(contents) -> Ok(contents)
    Error(err) -> {
      let msg = "failed to read ndjson: " <> simplifile.describe_error(err)
      log_error("import read-ndjson", msg)
      Error(msg)
    }
  }
}

fn write_csv(
  csv_path: String,
  cards: List(card_printing.CardPrinting),
) -> Result(String, String) {
  let csv_content = list.map(cards, card_to_csv_row) |> string.join("\n")
  case simplifile.write(csv_path, csv_content) {
    Ok(_) -> Ok(csv_path)
    Error(err) -> {
      let msg = "failed to write csv: " <> simplifile.describe_error(err)
      log_error("import write-csv", msg)
      shell.remove_file(csv_path)
      Error(msg)
    }
  }
}

// Transforms a downloaded Scryfall bulk-cards JSON Lines file into a CSV ready for
// bulk loading. Cleans up the intermediate ndjson on every exit path; cleans
// up a partial csv on its own error branches.
pub fn to_csv(download_path: String) -> Result(String, String) {
  let ndjson_path = download_path <> ".ndjson"
  let csv_path = download_path <> ".csv"
  use Nil <- result.try(run_jq(download_path, ndjson_path))
  use ndjson_contents <- result.try(read_ndjson(ndjson_path))
  let lines =
    string.split(ndjson_contents, "\n")
    |> list.filter(fn(line) { line != "" })
  let cards = validate_card_rows(lines)
  log(
    "import: validated "
    <> int.to_string(list.length(cards))
    <> "/"
    <> int.to_string(list.length(lines))
    <> " cards",
  )
  write_csv(csv_path, cards)
}

// One entry of the /sets response; nullable fields already defaulted.
type RawSet {
  RawSet(
    code: String,
    name: String,
    released_at: String,
    card_count: Int,
    printed_size: Option(Int),
    icon_svg_uri: String,
    parent_set_code: Option(String),
  )
}

fn raw_set_decoder() -> decode.Decoder(RawSet) {
  use code <- decode.field("code", decode.string)
  use name <- decode.field("name", decode.string)
  // Scryfall documents released_at and icon_svg_uri as nullable and may omit
  // the key instead of sending null; treat both shapes as unknown. A decode
  // failure here would hard-fail the refresh and re-trigger the full card bulk
  // import on every probe until fixed, so tolerate the cheap variants.
  use released_at <- decode.optional_field(
    "released_at",
    None,
    decode.optional(decode.string),
  )
  use card_count <- decode.field("card_count", decode.int)
  // Scryfall documents printed_size as nullable and may omit the key; treat both
  // shapes as unknown. Same tolerance rationale as released_at/icon_svg_uri.
  use printed_size <- decode.optional_field(
    "printed_size",
    None,
    decode.optional(decode.int),
  )
  use icon_svg_uri <- decode.optional_field(
    "icon_svg_uri",
    None,
    decode.optional(decode.string),
  )
  // parent_set_code links tokens/promos/etc. to their parent set; nullable and
  // omitted for root sets. Same tolerance rationale as released_at.
  use parent_set_code <- decode.optional_field(
    "parent_set_code",
    None,
    decode.optional(decode.string),
  )
  decode.success(RawSet(
    code:,
    name:,
    released_at: option.unwrap(released_at, ""),
    card_count:,
    printed_size:,
    icon_svg_uri: option.unwrap(icon_svg_uri, ""),
    parent_set_code:,
  ))
}

// An invalid set is logged and dropped rather than failing the whole page.
fn to_card_set(raw: RawSet) -> Result(card_set.CardSet, Nil) {
  case
    card_set.from_raw(
      code: raw.code,
      name: raw.name,
      released_at: raw.released_at,
      card_count: raw.card_count,
      printed_size: raw.printed_size,
      icon_svg_uri: raw.icon_svg_uri,
      parent_set_code: raw.parent_set_code,
    )
  {
    Ok(set) -> Ok(set)
    Error(reason) -> {
      log_warn("skipped invalid set: " <> reason)
      Error(Nil)
    }
  }
}

// Decodes one page of the Scryfall /sets response. Returns the sets on this
// page and the next-page URL (Some only when has_more is true).
pub fn parse_sets_page(
  json_str: String,
) -> Result(#(List(card_set.CardSet), Option(String)), String) {
  let page_decoder = {
    use has_more <- decode.field("has_more", decode.bool)
    use next_page <- decode.optional_field(
      "next_page",
      None,
      decode.optional(decode.string),
    )
    use data <- decode.field("data", decode.list(raw_set_decoder()))
    decode.success(#(has_more, next_page, data))
  }
  use #(has_more, next_page, raw_sets) <- result.try(
    json.parse(from: json_str, using: page_decoder)
    // nolint: string_inspect -- json.DecodeError has no string form; this only feeds the operator log
    |> result.map_error(fn(e) { "invalid sets json: " <> string.inspect(e) }),
  )
  let next = case has_more {
    True -> next_page
    False -> None
  }
  Ok(#(list.filter_map(raw_sets, to_card_set), next))
}
