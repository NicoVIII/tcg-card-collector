import catalog/domain/card_printing
import catalog/domain/card_rarity
import common/non_empty_string
import common/os_runtime
import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import infrastructure/stores/sqlite_store
import simplifile

type CatalogRowTuple =
  #(String, String, String)

const bulk_metadata_url = "https://api.scryfall.com/bulk-data/default_cards"

const shell_timeout_seconds = "540"

pub type RefreshIO {
  RefreshIO(download: fn(String) -> Result(String, String))
}

pub fn is_probe_due() -> Bool {
  let output =
    sqlite_store.query(
      "SELECT last_probe_at "
      <> "FROM catalog_sync_metadata "
      <> "WHERE id = 1 "
      <> "  AND last_refresh_status IN ('succeeded', 'skipped') "
      <> "  AND last_probe_at >= datetime('now', '-1 day') "
      <> "LIMIT 1;",
    )

  string.trim(output) == ""
}

pub fn current_upstream_updated_at() -> String {
  sqlite_store.query(
    "SELECT COALESCE(last_upstream_updated_at, '') "
    <> "FROM catalog_sync_metadata "
    <> "WHERE id = 1 LIMIT 1;",
  )
  |> string.trim
}

pub fn fetch_metadata(io: RefreshIO) -> Result(#(String, String), String) {
  case io.download(bulk_metadata_url) {
    Error(reason) -> {
      let simplified = simplify_error(reason)
      log_error("metadata download", simplified)
      Error(simplified)
    }
    Ok(path) -> {
      let script =
        "jq -r '[.updated_at, .download_uri] | @tsv' < " <> shell_quote(path)
      case run_shell(script) {
        Error(output) -> {
          let simplified = simplify_error(output)
          log_error("metadata jq parse", simplified)
          Error(simplified)
        }
        Ok(output) ->
          case string.split(string.trim(output), "\t") {
            [updated_at, download_uri] ->
              case updated_at != "" && download_uri != "" {
                True -> {
                  log(
                    "metadata ok: updated_at="
                    <> updated_at
                    <> " uri="
                    <> download_uri,
                  )
                  Ok(#(updated_at, download_uri))
                }
                False -> {
                  log_error(
                    "metadata parse",
                    "invalid metadata response from scryfall (empty fields in: "
                      <> string.trim(output)
                      <> ")",
                  )
                  Error("invalid metadata response from scryfall")
                }
              }
            _ -> {
              log_error(
                "metadata parse",
                "invalid metadata response from scryfall (unexpected tsv: "
                  <> string.trim(output)
                  <> ")",
              )
              Error("invalid metadata response from scryfall")
            }
          }
      }
    }
  }
}

pub fn import_cards(
  io: RefreshIO,
  download_uri: String,
) -> Result(Nil, String) {
  let _ = sqlite_store.exec("SELECT 1;")
  log("import: downloading " <> download_uri)
  case io.download(download_uri) {
    Error(reason) -> {
      let simplified = simplify_error(reason)
      log_error("import download", simplified)
      Error(simplified)
    }
    Ok(path) -> {
      let ndjson_path = path <> ".ndjson"
      let csv_path = path <> ".csv"
      let cleanup = fn() {
        let _ =
          run_shell(
            "rm -f " <> shell_quote(ndjson_path) <> " " <> shell_quote(csv_path),
          )
        Nil
      }
      let jq_script =
        "jq -c '.[] | {id: (.id // \"\"), name: (.name // \"\"), set_code: (.set // \"\"), collector_number: (.collector_number // \"\"), rarity: (.rarity // \"unknown\"), image_uri: (.image_uris.small // \"\")}' < "
        <> shell_quote(path)
        <> " > "
        <> shell_quote(ndjson_path)
      case run_shell(jq_script) {
        Error(output) -> {
          let simplified = simplify_error(output)
          log_error("import jq->ndjson", simplified)
          cleanup()
          Error(simplified)
        }
        Ok(_) -> {
          log("import: jq->ndjson ok")
          case simplifile.read(ndjson_path) {
            Error(err) -> {
              let msg = "failed to read ndjson: " <> string.inspect(err)
              log_error("import read-ndjson", msg)
              cleanup()
              Error(msg)
            }
            Ok(ndjson_contents) -> {
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
                  cleanup()
                  Error(msg)
                }
                Ok(_) -> {
                  let sqlite_script =
                    "set -e; "
                    <> "sqltmp=$(mktemp); "
                    <> "trap 'rm -f \"$sqltmp\"' EXIT; "
                    <> "printf '%s\\n' "
                    <> "\"BEGIN;\" "
                    <> "\"CREATE TEMP TABLE _catalog_import (\" "
                    <> "\"  id TEXT,\" "
                    <> "\"  name TEXT,\" "
                    <> "\"  set_code TEXT,\" "
                    <> "\"  collector_number TEXT,\" "
                    <> "\"  rarity TEXT,\" "
                    <> "\"  image_uri TEXT\" "
                    <> "\");\" "
                    <> "\".mode csv\" "
                    <> "\".import "
                    <> csv_path
                    <> " _catalog_import\" "
                    <> "\"DELETE FROM catalog_cards;\" "
                    <> "\"INSERT INTO catalog_cards (\" "
                    <> "\"  id, name, set_code, collector_number, rarity, image_uri\" "
                    <> "\")\" "
                    <> "\"SELECT\" "
                    <> "\"  id, name, set_code, collector_number, rarity, image_uri\" "
                    <> "\"FROM _catalog_import;\" "
                    <> "\"DROP TABLE _catalog_import;\" "
                    <> "\"COMMIT;\" > \"$sqltmp\"; "
                    <> "sqlite3 "
                    <> shell_quote(sqlite_store.db_file())
                    <> " < \"$sqltmp\""
                  case run_shell(sqlite_script) {
                    Ok(_) -> {
                      log("import: sqlite load ok")
                      cleanup()
                      Ok(Nil)
                    }
                    Error(output) -> {
                      let simplified = simplify_error(output)
                      log_error("import sqlite", simplified)
                      cleanup()
                      Error(simplified)
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
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

fn parse_card_row(line: String) -> Result(card_printing.CardPrinting, String) {
  let row_decoder = {
    use id <- decode.field("id", decode.string)
    use name <- decode.field("name", decode.string)
    use set_code <- decode.field("set_code", decode.string)
    use collector_number <- decode.field("collector_number", decode.string)
    use rarity <- decode.field("rarity", decode.string)
    use image_uri <- decode.field("image_uri", decode.string)
    decode.success(#(id, name, set_code, collector_number, rarity, image_uri))
  }
  case json.parse(from: line, using: row_decoder) {
    Error(_) ->
      Error(
        "invalid json: " <> string.slice(from: line, at_index: 0, length: 80),
      )
    Ok(#(id, name, set_code, collector_number, rarity, image_uri)) ->
      card_printing.from_raw(
        id: id,
        name: name,
        set_code: set_code,
        collector_number: collector_number,
        rarity: rarity,
        image_uri: image_uri,
      )
      |> result.map_error(fn(err) { card_error_to_string(id, err) })
  }
}

fn card_error_to_string(
  id: String,
  err: card_printing.CardPrintingError,
) -> String {
  let reason = case err {
    card_printing.EmptyName -> "empty name"
    card_printing.EmptySetCode -> "empty set_code"
    card_printing.EmptyCollectorNumber -> "empty collector_number"
    card_printing.UnknownRarity(r) -> "unknown rarity: " <> r
  }
  "id=" <> id <> " " <> reason
}

fn card_to_csv_row(card: card_printing.CardPrinting) -> String {
  let card_printing.CardPrinting(
    id: card_printing.CardPrintingId(id),
    key: key,
    name: name,
    rarity: rarity,
    image_uri: card_printing.ImageUri(image_uri),
  ) = card
  csv_field(id)
  <> ","
  <> csv_field(non_empty_string.to_string(name))
  <> ","
  <> csv_field(non_empty_string.to_string(key.set_code))
  <> ","
  <> csv_field(non_empty_string.to_string(key.collector_number))
  <> ","
  <> csv_field(card_rarity.to_string(rarity))
  <> ","
  <> csv_field(image_uri)
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

pub fn mark_probe_succeeded(updated_at: String) -> Nil {
  let sql =
    "INSERT INTO catalog_sync_metadata ("
    <> "  id, last_probe_at, last_upstream_updated_at, last_refresh_status, last_error_message, updated_at"
    <> ") VALUES ("
    <> "  1, CURRENT_TIMESTAMP, "
    <> sqlite_store.quote(updated_at)
    <> ", 'succeeded', NULL, CURRENT_TIMESTAMP"
    <> ") "
    <> "ON CONFLICT(id) DO UPDATE SET "
    <> "  last_probe_at = CURRENT_TIMESTAMP,"
    <> "  last_upstream_updated_at = excluded.last_upstream_updated_at,"
    <> "  last_refresh_status = 'succeeded',"
    <> "  last_error_message = NULL,"
    <> "  updated_at = CURRENT_TIMESTAMP;"

  sqlite_store.exec(sql)
}

pub fn mark_probe_skipped(updated_at: String) -> Nil {
  let sql =
    "INSERT INTO catalog_sync_metadata ("
    <> "  id, last_probe_at, last_upstream_updated_at, last_refresh_status, last_error_message, updated_at"
    <> ") VALUES ("
    <> "  1, CURRENT_TIMESTAMP, "
    <> sqlite_store.quote(updated_at)
    <> ", 'skipped', NULL, CURRENT_TIMESTAMP"
    <> ") "
    <> "ON CONFLICT(id) DO UPDATE SET "
    <> "  last_probe_at = CURRENT_TIMESTAMP,"
    <> "  last_upstream_updated_at = excluded.last_upstream_updated_at,"
    <> "  last_refresh_status = 'skipped',"
    <> "  last_error_message = NULL,"
    <> "  updated_at = CURRENT_TIMESTAMP;"

  sqlite_store.exec(sql)
}

pub fn mark_probe_failed(reason: String) -> Nil {
  let sql =
    "INSERT INTO catalog_sync_metadata ("
    <> "  id, last_probe_at, last_upstream_updated_at, last_refresh_status, last_error_message, updated_at"
    <> ") VALUES ("
    <> "  1, CURRENT_TIMESTAMP, NULL, 'failed', "
    <> sqlite_store.quote(reason)
    <> ", CURRENT_TIMESTAMP"
    <> ") "
    <> "ON CONFLICT(id) DO UPDATE SET "
    <> "  last_probe_at = CURRENT_TIMESTAMP,"
    <> "  last_refresh_status = 'failed',"
    <> "  last_error_message = excluded.last_error_message,"
    <> "  updated_at = CURRENT_TIMESTAMP;"

  sqlite_store.exec(sql)
}

pub fn list() -> List(CatalogRowTuple) {
  let output =
    sqlite_store.query(
      "SELECT id, name, set_code "
      <> "FROM catalog_cards "
      <> "ORDER BY name ASC, set_code ASC, collector_number ASC, id ASC;",
    )

  parse_rows(output)
}

fn run_shell(script: String) -> Result(String, String) {
  let wrapped =
    "set +e; " <> script <> "; status=$?; printf '\n__EXIT__:%s' \"$status\""

  let command =
    "timeout --signal=TERM --kill-after=10 "
    <> shell_timeout_seconds
    <> " sh -c "
    <> shell_quote(wrapped)

  let output = os_runtime.cmd(command)

  case string.split(output, "__EXIT__:") {
    [body, status_raw] ->
      case string.trim(status_raw) {
        "0" -> Ok(string.trim(body))
        _ -> Error(string.trim(body))
      }
    _ -> Error(string.trim(output))
  }
}

fn simplify_error(output: String) -> String {
  let trimmed = string.trim(output)
  case trimmed == "" {
    True -> "unknown error"
    False -> trimmed
  }
}

fn shell_quote(value: String) -> String {
  "'" <> string.replace(value, "'", "'\"'\"'") <> "'"
}

pub fn name_lookup() -> List(#(String, String, String)) {
  let output =
    sqlite_store.query(
      "SELECT set_code, collector_number, name "
      <> "FROM catalog_cards "
      <> "ORDER BY set_code ASC, collector_number ASC;",
    )

  output
  |> string.split("\n")
  |> list.filter_map(fn(line) {
    case line == "" {
      True -> Error(Nil)
      False ->
        case string.split(line, "\t") {
          [set_code, collector_number, name] ->
            Ok(#(set_code, collector_number, name))
          _ -> Error(Nil)
        }
    }
  })
}

fn parse_rows(output: String) -> List(CatalogRowTuple) {
  output
  |> string.split("\n")
  |> list.filter_map(fn(line) {
    case line == "" {
      True -> Error(Nil)
      False ->
        case string.split(line, "\t") {
          [id, name, set_code] -> Ok(#(id, name, set_code))
          _ -> Error(Nil)
        }
    }
  })
}

fn log(message: String) -> Nil {
  io.println("[refresh] " <> message)
}

fn log_warn(detail: String) -> Nil {
  io.println("[refresh][warn] " <> detail)
}

fn log_error(stage: String, detail: String) -> Nil {
  io.println("[refresh][error] " <> stage <> ": " <> detail)
}
