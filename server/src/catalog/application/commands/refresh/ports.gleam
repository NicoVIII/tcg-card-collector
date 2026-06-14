import catalog/domain/refresh_record.{type RefreshRecord}
import common/timestamp.{type Timestamp}

pub type BulkMetadata {
  BulkMetadata(updated_at: String, download_uri: String)
}

pub type NowPort =
  fn() -> Timestamp

pub type FetchMetadataPort =
  fn() -> Result(BulkMetadata, String)

pub type ImportCardsPort =
  fn(String) -> Result(Nil, String)

pub type RefreshRecordRepositoryPort {
  RefreshRecordRepositoryPort(
    load: fn() -> RefreshRecord,
    save: fn(RefreshRecord) -> Nil,
  )
}

pub type RefreshCatalogPorts {
  RefreshCatalogPorts(
    now: NowPort,
    record_repository: RefreshRecordRepositoryPort,
    fetch_metadata: FetchMetadataPort,
    import_cards: ImportCardsPort,
  )
}

pub type RefreshCatalogError {
  RefreshCatalogError(message: String)
}
