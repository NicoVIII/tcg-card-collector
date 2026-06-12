import application/commands/database/refresh/ports
import common/os_runtime
import gleam/string
import infrastructure/stores/database/database_store

pub fn new() -> ports.RefreshDatabasePort {
  new_with_io(live_io())
}

pub fn new_with_io(io: database_store.RefreshIO) -> ports.RefreshDatabasePort {
  ports.RefreshDatabasePort(
    is_probe_due: database_store.is_probe_due,
    current_upstream_updated_at: database_store.current_upstream_updated_at,
    fetch_metadata: fn() {
      case database_store.fetch_metadata(io) {
        Error(msg) -> Error(msg)
        Ok(#(updated_at, download_uri)) ->
          Ok(ports.BulkMetadata(
            updated_at: updated_at,
            download_uri: download_uri,
          ))
      }
    },
    import_cards: fn(uri) { database_store.import_cards(io, uri) },
    record_succeeded: database_store.mark_probe_succeeded,
    record_skipped: database_store.mark_probe_skipped,
    record_failed: database_store.mark_probe_failed,
  )
}

// Uses a single fixed temp path so nothing accumulates between runs.
// The path is overwritten on each download; concurrent refreshes are not expected.
fn live_io() -> database_store.RefreshIO {
  let tmp_dir = os_runtime.getenv_or("TMPDIR", "/tmp")
  let download_path = tmp_dir <> "/tcg-refresh-download"
  database_store.RefreshIO(download: fn(url) {
    let script =
      "set +e; curl -fsSL --compressed --connect-timeout 10 --max-time 480 "
      <> shell_quote(url)
      <> " -o "
      <> shell_quote(download_path)
      <> "; status=$?; printf '\\n__EXIT__:%s' \"$status\""
    let output = os_runtime.cmd("sh -c " <> shell_quote(script))
    case string.split(output, "__EXIT__:") {
      [_, status_raw] ->
        case string.trim(status_raw) {
          "0" -> Ok(download_path)
          _ -> Error(string.trim(output))
        }
      _ -> Error(string.trim(output))
    }
  })
}

fn shell_quote(value: String) -> String {
  "'" <> string.replace(value, "'", "'\"'\"'") <> "'"
}
