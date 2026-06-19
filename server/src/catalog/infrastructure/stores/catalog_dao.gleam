import catalog/domain/refresh_record
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/time/timestamp
import infrastructure/shell
import infrastructure/stores/sqlite_store

type CatalogRowTuple =
  #(String, String, String)

fn log(message: String) -> Nil {
  io.println("[refresh] " <> message)
}

fn log_error(stage: String, detail: String) -> Nil {
  io.println("[refresh][error] " <> stage <> ": " <> detail)
}

pub fn load_refresh_record() -> Option(refresh_record.ProbeResult) {
  let output =
    sqlite_store.query(
      "SELECT strftime('%s', last_probe_at), last_upstream_updated_at, last_refresh_status, last_error_message "
      <> "FROM catalog_sync_metadata WHERE id = 1 LIMIT 1;",
    )
  // Split on newline first so the trailing tab for a NULL column is preserved
  // when we subsequently split on tab. string.trim would eat the trailing tab.
  let row =
    string.split(output, "\n")
    |> list.find(fn(line) { line != "" })
  case row {
    Error(_) -> None
    Ok(line) ->
      case string.split(line, "\t") {
        [epoch_str, upstream_at, status_str, error_msg] ->
          case int.parse(epoch_str) {
            Error(_) -> None
            Ok(epoch) -> {
              let last_probe_at = timestamp.from_unix_seconds(epoch)
              let last_upstream_updated_at = case upstream_at {
                "" -> None
                s -> Some(s)
              }
              let status = case status_str {
                "succeeded" -> refresh_record.Succeeded
                "skipped" -> refresh_record.Skipped
                "failed" -> refresh_record.Failed(error_msg)
                _ -> refresh_record.Failed("unknown status: " <> status_str)
              }
              Some(refresh_record.ProbeResult(
                last_probe_at:,
                last_upstream_updated_at:,
                status:,
              ))
            }
          }
        _ -> None
      }
  }
}

pub fn save_refresh_record(record: refresh_record.ProbeResult) -> Nil {
  let refresh_record.ProbeResult(
    last_probe_at:,
    last_upstream_updated_at:,
    status:,
  ) = record
  let #(epoch, _) = timestamp.to_unix_seconds_and_nanoseconds(last_probe_at)
  let upstream_at_sql = case last_upstream_updated_at {
    None -> "NULL"
    Some(s) -> sqlite_store.quote(s)
  }
  let #(status_str, error_msg_sql) = case status {
    refresh_record.Succeeded -> #("succeeded", "NULL")
    refresh_record.Skipped -> #("skipped", "NULL")
    refresh_record.Failed(reason) -> #("failed", sqlite_store.quote(reason))
  }
  let sql =
    "INSERT INTO catalog_sync_metadata ("
    <> "  id, last_probe_at, last_upstream_updated_at, last_refresh_status, last_error_message, updated_at"
    <> ") VALUES ("
    <> "  1, datetime("
    <> int.to_string(epoch)
    <> ", 'unixepoch'), "
    <> upstream_at_sql
    <> ", "
    <> sqlite_store.quote(status_str)
    <> ", "
    <> error_msg_sql
    <> ", CURRENT_TIMESTAMP"
    <> ") "
    <> "ON CONFLICT(id) DO UPDATE SET "
    <> "  last_probe_at = excluded.last_probe_at,"
    <> "  last_upstream_updated_at = excluded.last_upstream_updated_at,"
    <> "  last_refresh_status = excluded.last_refresh_status,"
    <> "  last_error_message = excluded.last_error_message,"
    <> "  updated_at = CURRENT_TIMESTAMP;"
  sqlite_store.exec(sql)
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

pub fn list() -> List(CatalogRowTuple) {
  let output =
    sqlite_store.query(
      "SELECT id, name, set_code "
      <> "FROM catalog_cards "
      <> "ORDER BY name ASC, set_code ASC, collector_number ASC, id ASC;",
    )
  parse_rows(output)
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

pub fn bulk_load(csv_path: String) -> Result(Nil, String) {
  let _ = sqlite_store.exec("SELECT 1;")
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
