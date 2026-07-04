import catalog/domain/refresh_record
import gleam/dynamic/decode
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/time/timestamp
import shared/infrastructure/shell
import shared/infrastructure/stores/sqlite_store
import sqlight

type CatalogKeyTuple =
  #(String, String)

// (set_code, collector_number, name, image_uri, rarity, oracle_id,
//  color_identity, type_line, released_at)
type CatalogCardTuple =
  #(String, String, String, String, String, String, String, String, String)

// SQLite caps bound parameters (default 999); get_by_keys binds 2 per key, so a
// real collection would overflow a single query. Mirror collection_dao's batch
// size and chunk the lookup.
const get_by_keys_batch_size = 100

fn log(message: String) -> Nil {
  io.println("[refresh] " <> message)
}

fn log_error(stage: String, detail: String) -> Nil {
  io.println("[refresh][error] " <> stage <> ": " <> detail)
}

fn refresh_record_row_decoder() {
  use epoch <- decode.field(0, decode.int)
  use last_upstream_updated_at <- decode.field(
    1,
    decode.optional(decode.string),
  )
  use status_str <- decode.field(2, decode.string)
  use error_msg <- decode.field(3, decode.optional(decode.string))
  decode.success(#(epoch, last_upstream_updated_at, status_str, error_msg))
}

pub fn load_refresh_record() -> Option(refresh_record.ProbeResult) {
  let rows =
    sqlite_store.query(
      "SELECT CAST(strftime('%s', last_probe_at) AS INTEGER), "
        <> "last_upstream_updated_at, last_refresh_status, last_error_message "
        <> "FROM catalog_sync_metadata WHERE id = 1 LIMIT 1;",
      [],
      refresh_record_row_decoder(),
    )
  case rows {
    Error(_) -> None
    Ok([]) -> None
    Ok([#(epoch, last_upstream_updated_at, status_str, error_msg), ..]) -> {
      let status = case status_str {
        "succeeded" -> refresh_record.Succeeded
        "skipped" -> refresh_record.Skipped
        "failed" ->
          refresh_record.Failed(option.unwrap(error_msg, "unknown error"))
        _ -> refresh_record.Failed("unknown status: " <> status_str)
      }
      Some(refresh_record.ProbeResult(
        last_probe_at: timestamp.from_unix_seconds(epoch),
        last_upstream_updated_at:,
        status:,
      ))
    }
  }
}

pub fn save_refresh_record(
  record: refresh_record.ProbeResult,
) -> Result(Nil, String) {
  let refresh_record.ProbeResult(
    last_probe_at:,
    last_upstream_updated_at:,
    status:,
  ) = record
  let #(epoch, _) = timestamp.to_unix_seconds_and_nanoseconds(last_probe_at)
  let #(status_str, error_msg) = case status {
    refresh_record.Succeeded -> #("succeeded", None)
    refresh_record.Skipped -> #("skipped", None)
    refresh_record.Failed(reason) -> #("failed", Some(reason))
  }
  let sql =
    "INSERT INTO catalog_sync_metadata ("
    <> "  id, last_probe_at, last_upstream_updated_at, last_refresh_status, last_error_message, updated_at"
    <> ") VALUES ("
    <> "  1, datetime(?, 'unixepoch'), ?, ?, ?, CURRENT_TIMESTAMP) "
    <> "ON CONFLICT(id) DO UPDATE SET "
    <> "  last_probe_at = excluded.last_probe_at,"
    <> "  last_upstream_updated_at = excluded.last_upstream_updated_at,"
    <> "  last_refresh_status = excluded.last_refresh_status,"
    <> "  last_error_message = excluded.last_error_message,"
    <> "  updated_at = CURRENT_TIMESTAMP;"
  let params = [
    sqlight.int(epoch),
    sqlight.nullable(sqlight.text, last_upstream_updated_at),
    sqlight.text(status_str),
    sqlight.nullable(sqlight.text, error_msg),
  ]
  sqlite_store.exec(sql, params)
  |> result.map_error(fn(error) { error.message })
}

fn key_row_decoder() {
  use set_code <- decode.field(0, decode.string)
  use collector_number <- decode.field(1, decode.string)
  decode.success(#(set_code, collector_number))
}

fn card_row_decoder() {
  use set_code <- decode.field(0, decode.string)
  use collector_number <- decode.field(1, decode.string)
  use name <- decode.field(2, decode.string)
  use image_uri <- decode.field(3, decode.string)
  use rarity <- decode.field(4, decode.string)
  use oracle_id <- decode.field(5, decode.string)
  use color_identity <- decode.field(6, decode.string)
  use type_line <- decode.field(7, decode.string)
  use released_at <- decode.field(8, decode.string)
  decode.success(#(
    set_code,
    collector_number,
    name,
    image_uri,
    rarity,
    oracle_id,
    color_identity,
    type_line,
    released_at,
  ))
}

pub fn list() -> List(CatalogKeyTuple) {
  sqlite_store.query(
    "SELECT set_code, collector_number "
      <> "FROM catalog_cards "
      <> "ORDER BY name ASC, set_code ASC, collector_number ASC;",
    [],
    key_row_decoder(),
  )
  |> result.unwrap([])
}

pub fn get_by_keys(keys: List(CatalogKeyTuple)) -> List(CatalogCardTuple) {
  keys
  |> list.sized_chunk(get_by_keys_batch_size)
  |> list.flat_map(get_by_keys_chunk)
}

fn get_by_keys_chunk(keys: List(CatalogKeyTuple)) -> List(CatalogCardTuple) {
  case keys {
    [] -> []
    _ -> {
      let placeholders =
        keys
        |> list.map(fn(_) { "(?,?)" })
        |> string.join(", ")
      let params =
        keys
        |> list.flat_map(fn(key) {
          let #(set_code, collector_number) = key
          [sqlight.text(set_code), sqlight.text(collector_number)]
        })
      sqlite_store.query(
        "SELECT set_code, collector_number, name, image_uri, rarity, "
          <> "oracle_id, color_identity, type_line, released_at "
          <> "FROM catalog_cards "
          <> "WHERE (set_code, collector_number) IN ("
          <> placeholders
          <> ");",
        params,
        card_row_decoder(),
      )
      |> result.unwrap([])
    }
  }
}

pub fn list_by_set_codes(set_codes: List(String)) -> List(CatalogKeyTuple) {
  case set_codes {
    [] -> []
    _ -> {
      let placeholders =
        set_codes
        |> list.map(fn(_) { "?" })
        |> string.join(", ")
      let params = list.map(set_codes, sqlight.text)
      sqlite_store.query(
        "SELECT DISTINCT set_code, collector_number "
          <> "FROM catalog_cards "
          <> "WHERE set_code IN ("
          <> placeholders
          <> ");",
        params,
        key_row_decoder(),
      )
      |> result.unwrap([])
    }
  }
}

fn name_row_decoder() {
  use set_code <- decode.field(0, decode.string)
  use collector_number <- decode.field(1, decode.string)
  use name <- decode.field(2, decode.string)
  decode.success(#(set_code, collector_number, name))
}

pub fn name_lookup() -> List(#(String, String, String)) {
  sqlite_store.query(
    "SELECT set_code, collector_number, name "
      <> "FROM catalog_cards "
      <> "ORDER BY set_code ASC, collector_number ASC;",
    [],
    name_row_decoder(),
  )
  |> result.unwrap([])
}

pub fn bulk_load(csv_path: String) -> Result(Nil, String) {
  let _ = sqlite_store.exec("SELECT 1;", [])
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
    <> "\"  image_uri TEXT,\" "
    <> "\"  oracle_id TEXT,\" "
    <> "\"  color_identity TEXT,\" "
    <> "\"  type_line TEXT,\" "
    <> "\"  released_at TEXT\" "
    <> "\");\" "
    <> "\".mode csv\" "
    <> "\".import "
    <> csv_path
    <> " _catalog_import\" "
    <> "\"DELETE FROM catalog_cards;\" "
    <> "\"INSERT INTO catalog_cards (\" "
    <> "\"  id, name, set_code, collector_number, rarity, image_uri,\" "
    <> "\"  oracle_id, color_identity, type_line, released_at\" "
    <> "\")\" "
    <> "\"SELECT\" "
    <> "\"  id, name, set_code, collector_number, rarity, image_uri,\" "
    <> "\"  oracle_id, color_identity, type_line, released_at\" "
    <> "\"FROM _catalog_import;\" "
    <> "\"DROP TABLE _catalog_import;\" "
    <> "\"COMMIT;\" > \"$sqltmp\"; "
    <> "sqlite3 "
    <> shell.quote(sqlite_store.db_file())
    <> " < \"$sqltmp\""
  case shell.run(sqlite_script) {
    Ok(_) -> {
      log("import: sqlite load ok")
      Ok(Nil)
    }
    Error(output) -> {
      let simplified = shell.simplify_error(output)
      log_error("import sqlite", simplified)
      Error(simplified)
    }
  }
}
