import catalog/domain/card_printing
import catalog/domain/card_set
import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None}
import gleam/string
import shared/domain/card_key
import shared/domain/non_empty_string
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

fn parse_rarity(raw: String) -> Result(card_printing.CardRarity, Nil) {
  case raw {
    "common" -> Ok(card_printing.Common)
    "uncommon" -> Ok(card_printing.Uncommon)
    "rare" -> Ok(card_printing.Rare)
    "mythic" -> Ok(card_printing.Mythic)
    "special" -> Ok(card_printing.Special)
    "bonus" -> Ok(card_printing.Bonus)
    _ -> Error(Nil)
  }
}

fn rarity_to_string(rarity: card_printing.CardRarity) -> String {
  case rarity {
    card_printing.Common -> "common"
    card_printing.Uncommon -> "uncommon"
    card_printing.Rare -> "rare"
    card_printing.Mythic -> "mythic"
    card_printing.Special -> "special"
    card_printing.Bonus -> "bonus"
  }
}

fn parse_card_row(line: String) -> Result(card_printing.CardPrinting, String) {
  let row_decoder = {
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
    decode.success(#(
      id,
      name,
      set_code,
      collector_number,
      rarity,
      image_uri,
      oracle_id,
      color_identity,
      type_line,
      released_at,
    ))
  }
  case json.parse(from: line, using: row_decoder) {
    Error(_) ->
      Error(
        "invalid json: " <> string.slice(from: line, at_index: 0, length: 80),
      )
    Ok(#(
      id,
      name,
      set_code,
      collector_number,
      rarity,
      image_uri,
      oracle_id,
      color_identity,
      type_line,
      released_at,
    )) ->
      case non_empty_string.new(name) {
        Error(_) -> Error("id=" <> id <> " empty name")
        Ok(name_nes) ->
          case card_key.new(set_code:, collector_number:) {
            Error(card_key.EmptySetCode) ->
              Error("id=" <> id <> " empty set_code")
            Error(card_key.EmptyCollectorNumber) ->
              Error("id=" <> id <> " empty collector_number")
            Error(card_key.SetCodeNotCanonical) ->
              Error("id=" <> id <> " set_code not canonical")
            Error(card_key.CollectorNumberNotCanonical) ->
              Error("id=" <> id <> " collector_number not canonical")
            Ok(key) ->
              case parse_rarity(rarity) {
                Error(_) -> Error("id=" <> id <> " unknown rarity: " <> rarity)
                Ok(rarity_val) ->
                  case non_empty_string.new(image_uri) {
                    Error(_) -> Error("id=" <> id <> " empty image_uri")
                    Ok(image_uri_nes) ->
                      // oracle_id/color_identity/type_line/released_at are
                      // carried verbatim; empty values are tolerated (see
                      // card_printing) because reversible/multi-face layouts
                      // may expose no top-level value.
                      Ok(card_printing.CardPrinting(
                        id: card_printing.CardPrintingId(id),
                        key:,
                        name: name_nes,
                        rarity: rarity_val,
                        image_uri: image_uri_nes,
                        oracle_id:,
                        color_identity:,
                        type_line:,
                        released_at:,
                      ))
                  }
              }
          }
      }
  }
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
    rarity: rarity,
    image_uri: image_uri,
    oracle_id: oracle_id,
    color_identity: color_identity,
    type_line: type_line,
    released_at: released_at,
  ) = card
  csv_field(id)
  <> ","
  <> csv_field(non_empty_string.to_string(name))
  <> ","
  <> csv_field(card_key.set_code_string(key))
  <> ","
  <> csv_field(card_key.collector_number_string(key))
  <> ","
  <> csv_field(rarity_to_string(rarity))
  <> ","
  <> csv_field(non_empty_string.to_string(image_uri))
  <> ","
  <> csv_field(oracle_id)
  <> ","
  <> csv_field(color_identity)
  <> ","
  <> csv_field(type_line)
  <> ","
  <> csv_field(released_at)
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

fn set_object_decoder() {
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
  use icon_svg_uri <- decode.optional_field(
    "icon_svg_uri",
    None,
    decode.optional(decode.string),
  )
  decode.success(#(
    code,
    name,
    option.unwrap(released_at, ""),
    card_count,
    option.unwrap(icon_svg_uri, ""),
  ))
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
    use data <- decode.field("data", decode.list(set_object_decoder()))
    decode.success(#(has_more, next_page, data))
  }
  case json.parse(from: json_str, using: page_decoder) {
    Error(e) -> Error("invalid sets json: " <> string.inspect(e))
    Ok(#(has_more, next_page, raw_sets)) -> {
      let sets =
        list.filter_map(raw_sets, fn(raw) {
          let #(code, name, released_at, card_count, icon_svg_uri) = raw
          case
            card_set.from_raw(
              code: code,
              name: name,
              released_at: released_at,
              card_count: card_count,
              icon_svg_uri: icon_svg_uri,
            )
          {
            Ok(s) -> Ok(s)
            Error(reason) -> {
              log_warn("skipped invalid set: " <> reason)
              Error(Nil)
            }
          }
        })
      let next = case has_more {
        True -> next_page
        False -> None
      }
      Ok(#(sets, next))
    }
  }
}

// Transforms a downloaded Scryfall bulk-cards JSON file into a CSV ready for
// bulk loading. Cleans up the intermediate ndjson on every exit path; cleans
// up a partial csv on its own error branches.
pub fn to_csv(download_path: String) -> Result(String, String) {
  let ndjson_path = download_path <> ".ndjson"
  let csv_path = download_path <> ".csv"
  // Enrichment fields tolerate multi-face/reversible layouts that expose no
  // top-level value: fall back to the first card face, then to "". color_identity
  // is a WUBRG letter array joined into a canonical-ish string; planning
  // re-canonicalizes at its port boundary.
  let jq_script =
    "jq -c '.[] | {id: (.id // \"\"), name: (.name // \"\"), set_code: (.set // \"\"), collector_number: (.collector_number // \"\"), rarity: (.rarity // \"unknown\"), image_uri: (.image_uris.small // .card_faces[0].image_uris.small // \"\"), oracle_id: (.oracle_id // .card_faces[0].oracle_id // \"\"), color_identity: ((.color_identity // []) | join(\"\")), type_line: (.type_line // .card_faces[0].type_line // \"\"), released_at: (.released_at // \"\")}' < "
    <> shell.quote(download_path)
    <> " > "
    <> shell.quote(ndjson_path)
  case shell.run(jq_script) {
    Error(output) -> {
      let simplified = shell.simplify_error(output)
      log_error("import jq->ndjson", simplified)
      let _ = shell.run("rm -f " <> shell.quote(ndjson_path))
      Error(simplified)
    }
    Ok(_) -> {
      log("import: jq->ndjson ok")
      case simplifile.read(ndjson_path) {
        Error(err) -> {
          let msg = "failed to read ndjson: " <> string.inspect(err)
          log_error("import read-ndjson", msg)
          let _ = shell.run("rm -f " <> shell.quote(ndjson_path))
          Error(msg)
        }
        Ok(ndjson_contents) -> {
          // ndjson has been read into memory; remove it before the csv step
          let _ = shell.run("rm -f " <> shell.quote(ndjson_path))
          let lines =
            string.split(ndjson_contents, "\n")
            |> list.filter(fn(line) { line != "" })
          let total = list.length(lines)
          let cards = validate_card_rows(lines)
          let valid_count = list.length(cards)
          log(
            "import: validated "
            <> int.to_string(valid_count)
            <> "/"
            <> int.to_string(total)
            <> " cards",
          )
          let csv_content =
            list.map(cards, card_to_csv_row) |> string.join("\n")
          case simplifile.write(csv_path, csv_content) {
            Error(err) -> {
              let msg = "failed to write csv: " <> string.inspect(err)
              log_error("import write-csv", msg)
              let _ = shell.run("rm -f " <> shell.quote(csv_path))
              Error(msg)
            }
            Ok(_) -> Ok(csv_path)
          }
        }
      }
    }
  }
}
