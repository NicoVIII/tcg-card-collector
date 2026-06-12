import common/os_runtime
import gleam/list
import gleam/string
import infrastructure/stores/sqlite_store

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
    Error(reason) -> Error(simplify_error(reason))
    Ok(path) -> {
      let script =
        "jq -r '[.updated_at, .download_uri] | @tsv' < " <> shell_quote(path)
      case run_shell(script) {
        Error(output) -> Error(simplify_error(output))
        Ok(output) ->
          case string.split(string.trim(output), "\t") {
            [updated_at, download_uri] ->
              case updated_at != "" && download_uri != "" {
                True -> Ok(#(updated_at, download_uri))
                False -> Error("invalid metadata response from scryfall")
              }
            _ -> Error("invalid metadata response from scryfall")
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
  case io.download(download_uri) {
    Error(reason) -> Error(simplify_error(reason))
    Ok(path) -> {
      let script =
        "set -e; "
        <> "sqltmp=$(mktemp); "
        <> "trap 'rm -f \"$sqltmp\"' EXIT; "
        <> "tmp="
        <> shell_quote(path)
        <> "; "
        <> "jq -r '.[] | [(.id // \"\"), (.oracle_id // \"\"), (.name // \"\"), (.set // \"\"), (.collector_number // \"\"), (.rarity // \"unknown\"), (.image_uris.small // \"\"), (.image_uris.normal // \"\")] | @csv' < \"$tmp\" > \"${tmp}.csv\"; "
        <> "printf '%s\\n' "
        <> "\"BEGIN;\" "
        <> "\"CREATE TEMP TABLE _catalog_import (\" "
        <> "\"  id TEXT,\" "
        <> "\"  oracle_id TEXT,\" "
        <> "\"  name TEXT,\" "
        <> "\"  set_code TEXT,\" "
        <> "\"  collector_number TEXT,\" "
        <> "\"  rarity TEXT,\" "
        <> "\"  image_small_uri TEXT,\" "
        <> "\"  image_normal_uri TEXT\" "
        <> "\");\" "
        <> "\".mode csv\" "
        <> "\".import ${tmp}.csv _catalog_import\" "
        <> "\"DELETE FROM catalog_cards;\" "
        <> "\"INSERT INTO catalog_cards (\" "
        <> "\"  id, oracle_id, name, set_code, collector_number, rarity, image_small_uri, image_normal_uri\" "
        <> "\")\" "
        <> "\"SELECT\" "
        <> "\"  id, oracle_id, name, set_code, collector_number, rarity, image_small_uri, image_normal_uri\" "
        <> "\"FROM _catalog_import;\" "
        <> "\"DROP TABLE _catalog_import;\" "
        <> "\"COMMIT;\" > \"$sqltmp\"; "
        <> "sqlite3 "
        <> shell_quote(sqlite_store.db_file())
        <> " < \"$sqltmp\"; "
        <> "rm -f \"${tmp}.csv\""

      case run_shell(script) {
        Ok(_) -> Ok(Nil)
        Error(output) -> Error(simplify_error(output))
      }
    }
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
