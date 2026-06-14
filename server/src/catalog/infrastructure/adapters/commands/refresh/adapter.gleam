import catalog/application/commands/refresh/ports
import catalog/infrastructure/adapters/commands/refresh/now_adapter
import catalog/infrastructure/stores/catalog_store
import common/os_runtime
import gleam/string

pub fn new() -> ports.RefreshCatalogPorts {
  new_with_io(live_io())
}

pub fn new_with_io(io: catalog_store.RefreshIO) -> ports.RefreshCatalogPorts {
  ports.RefreshCatalogPorts(
    now: now_adapter.get_now(),
    record_repository: record_repository_adapter(),
    fetch_metadata: fetch_metadata_adapter(io),
    import_cards: import_cards_adapter(io),
  )
}

fn record_repository_adapter() -> ports.RefreshRecordRepositoryPort {
  ports.RefreshRecordRepositoryPort(
    load: catalog_store.load_refresh_record,
    save: catalog_store.save_refresh_record,
  )
}

fn fetch_metadata_adapter(
  io: catalog_store.RefreshIO,
) -> ports.FetchMetadataPort {
  fn() {
    case catalog_store.fetch_metadata(io) {
      Error(msg) -> Error(msg)
      Ok(#(updated_at, download_uri)) ->
        Ok(ports.BulkMetadata(
          updated_at: updated_at,
          download_uri: download_uri,
        ))
    }
  }
}

fn import_cards_adapter(io: catalog_store.RefreshIO) -> ports.ImportCardsPort {
  fn(uri) { catalog_store.import_cards(io, uri) }
}

// Uses a single fixed temp path so nothing accumulates between runs.
// The path is overwritten on each download; concurrent refreshes are not expected.
fn live_io() -> catalog_store.RefreshIO {
  let tmp_dir = os_runtime.getenv_or("TMPDIR", "/tmp")
  let download_path = tmp_dir <> "/tcg-refresh-download"
  catalog_store.RefreshIO(download: fn(url) {
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
