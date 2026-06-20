import catalog/application/commands/refresh/ports
import catalog/infrastructure/adapters/commands/refresh/now_adapter
import catalog/infrastructure/clients/scryfall_client
import catalog/infrastructure/clients/scryfall_mapper
import catalog/infrastructure/daos/catalog_dao
import gleam/result
import shared/infrastructure/shell

pub fn new() -> ports.RefreshCatalogPorts {
  new_with_downloader(scryfall_client.live_downloader())
}

pub fn new_with_downloader(
  downloader: scryfall_client.Downloader,
) -> ports.RefreshCatalogPorts {
  ports.RefreshCatalogPorts(
    now: now_adapter.create(),
    record_repository: record_repository_adapter(),
    fetch_metadata: fetch_metadata_adapter(downloader),
    import_cards: import_cards_adapter(downloader),
  )
}

fn record_repository_adapter() -> ports.RefreshRecordRepositoryPort {
  ports.RefreshRecordRepositoryPort(
    load: catalog_dao.load_refresh_record,
    save: catalog_dao.save_refresh_record,
  )
}

fn fetch_metadata_adapter(
  downloader: scryfall_client.Downloader,
) -> ports.FetchMetadataPort {
  fn() {
    case scryfall_client.fetch_metadata(downloader) {
      Error(msg) -> Error(msg)
      Ok(#(updated_at, download_uri)) ->
        Ok(ports.BulkMetadata(updated_at:, download_uri:))
    }
  }
}

fn import_cards_adapter(
  downloader: scryfall_client.Downloader,
) -> ports.ImportCardsPort {
  fn(uri) {
    use path <- result.try(scryfall_client.download_cards(downloader, uri))
    use csv_path <- result.try(scryfall_mapper.to_csv(path))
    let outcome = catalog_dao.bulk_load(csv_path)
    // Orchestrator owns the csv lifecycle; mapper handled its own ndjson.
    let _ = shell.run("rm -f " <> shell.quote(csv_path))
    outcome
  }
}
