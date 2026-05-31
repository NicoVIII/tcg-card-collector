import common/os_runtime
import gleam/list
import gleam/string
import infrastructure/sqlite_store

type CatalogRowTuple =
  #(String, String, String)

const bulk_metadata_url = "https://api.scryfall.com/bulk-data/default_cards"

const shell_timeout_seconds = "300"

const curl_connect_timeout_seconds = "10"

const curl_metadata_max_time_seconds = "30"

const curl_bulk_import_max_time_seconds = "240"

pub fn refresh() -> Result(Nil, String) {
  case should_probe() {
    False -> Ok(Nil)
    True ->
      case fetch_bulk_metadata() {
        Error(reason) -> {
          mark_probe_failed(reason)
          Error(reason)
        }
        Ok(#(updated_at, download_uri)) ->
          case current_upstream_updated_at() {
            value if value == updated_at -> {
              mark_probe_skipped(updated_at)
              Ok(Nil)
            }
            _ ->
              case import_cards(download_uri) {
                Ok(_) -> {
                  mark_probe_succeeded(updated_at)
                  Ok(Nil)
                }
                Error(reason) -> {
                  mark_probe_failed(reason)
                  Error("catalog refresh failed: " <> reason)
                }
              }
          }
      }
  }
}

pub fn upsert(id: String, name: String, set_code: String) -> Nil {
  let sql =
    "INSERT INTO catalog_cards ("
    <> "  id, oracle_id, name, set_code, collector_number, rarity, image_small_uri, image_normal_uri"
    <> ") VALUES ("
    <> sqlite_store.quote(id)
    <> ", "
    <> sqlite_store.quote(id)
    <> ", "
    <> sqlite_store.quote(name)
    <> ", "
    <> sqlite_store.quote(set_code)
    <> ", ''"
    <> ", 'unknown'"
    <> ", ''"
    <> ", ''"
    <> ") "
    <> "ON CONFLICT(id) DO UPDATE SET "
    <> "  oracle_id = excluded.oracle_id,"
    <> "  name = excluded.name,"
    <> "  set_code = excluded.set_code,"
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

pub fn clear() -> Nil {
  sqlite_store.exec("DELETE FROM catalog_cards;")
  sqlite_store.exec("DELETE FROM catalog_sync_metadata;")
}

fn should_probe() -> Bool {
  let output =
    sqlite_store.query(
      "SELECT last_probe_at "
      <> "FROM catalog_sync_metadata "
      <> "WHERE id = 1 AND last_probe_at >= datetime('now', '-1 day') "
      <> "LIMIT 1;",
    )

  string.trim(output) == ""
}

fn current_upstream_updated_at() -> String {
  sqlite_store.query(
    "SELECT COALESCE(last_upstream_updated_at, '') "
    <> "FROM catalog_sync_metadata "
    <> "WHERE id = 1 LIMIT 1;",
  )
  |> string.trim
}

fn fetch_bulk_metadata() -> Result(#(String, String), String) {
  let script =
    "set -e; "
    <> "curl -fsSL --connect-timeout "
    <> curl_connect_timeout_seconds
    <> " --max-time "
    <> curl_metadata_max_time_seconds
    <> " "
    <> shell_quote(bulk_metadata_url)
    <> " | jq -r '[.updated_at, .download_uri] | @tsv'"

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

fn import_cards(download_uri: String) -> Result(Nil, String) {
  let _ = sqlite_store.exec("SELECT 1;")
  let script =
    "set -e; "
    <> "tmp=$(mktemp); "
    <> "trap 'rm -f \"$tmp\"' EXIT; "
    <> "curl -fsSL --connect-timeout "
    <> curl_connect_timeout_seconds
    <> " --max-time "
    <> curl_bulk_import_max_time_seconds
    <> " "
    <> shell_quote(download_uri)
    <> " | jq -r '.[] | [.id, .oracle_id, .name, .set, (.collector_number // \"\"), (.rarity // \"unknown\"), (.image_uris.small // \"\"), (.image_uris.normal // \"\")] | @tsv' > \"$tmp\"; "
    <> "sqlite3 "
    <> shell_quote(sqlite_store.db_file())
    <> " <<SQL\n"
    <> "BEGIN;\n"
    <> "CREATE TEMP TABLE _catalog_import (\n"
    <> "  id TEXT,\n"
    <> "  oracle_id TEXT,\n"
    <> "  name TEXT,\n"
    <> "  set_code TEXT,\n"
    <> "  collector_number TEXT,\n"
    <> "  rarity TEXT,\n"
    <> "  image_small_uri TEXT,\n"
    <> "  image_normal_uri TEXT\n"
    <> ");\n"
    <> ".mode tabs\n"
    <> ".import $tmp _catalog_import\n"
    <> "DELETE FROM catalog_cards;\n"
    <> "INSERT INTO catalog_cards (\n"
    <> "  id, oracle_id, name, set_code, collector_number, rarity, image_small_uri, image_normal_uri\n"
    <> ")\n"
    <> "SELECT\n"
    <> "  id, oracle_id, name, set_code, collector_number, rarity, image_small_uri, image_normal_uri\n"
    <> "FROM _catalog_import;\n"
    <> "DROP TABLE _catalog_import;\n"
    <> "COMMIT;\n"
    <> "SQL"

  case run_shell(script) {
    Ok(_) -> Ok(Nil)
    Error(output) -> Error(simplify_error(output))
  }
}

fn mark_probe_succeeded(updated_at: String) -> Nil {
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

fn mark_probe_skipped(updated_at: String) -> Nil {
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

fn mark_probe_failed(reason: String) -> Nil {
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
