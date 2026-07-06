import catalog/domain/refresh_record.{type ProbeResult}
import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}

pub type BulkMetadata {
  BulkMetadata(updated_at: String, download_uri: String)
}

pub type NowPort =
  fn() -> Timestamp

pub type FetchMetadataPort =
  fn() -> Result(BulkMetadata, String)

pub type ImportCardsPort =
  fn(String) -> Result(Nil, String)

pub type ImportSetsPort =
  fn() -> Result(Nil, String)

pub type RefreshRecordRepositoryPort {
  RefreshRecordRepositoryPort(
    load: fn() -> Option(ProbeResult),
    save: fn(ProbeResult) -> Result(Nil, String),
  )
}

pub type RefreshCatalogPorts {
  RefreshCatalogPorts(
    now: NowPort,
    record_repository: RefreshRecordRepositoryPort,
    fetch_metadata: FetchMetadataPort,
    import_cards: ImportCardsPort,
    import_sets: ImportSetsPort,
  )
}

pub type RefreshCatalogError {
  RefreshCatalogError(reason: String)
}
