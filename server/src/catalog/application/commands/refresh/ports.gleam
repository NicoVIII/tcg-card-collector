import catalog/domain/refresh_record.{type RefreshRecord}
import common/timestamp.{type Timestamp}

pub type BulkMetadata {
  BulkMetadata(updated_at: String, download_uri: String)
}

pub type RefreshCatalogPort {
  RefreshCatalogPort(
    now: fn() -> Timestamp,
    load_record: fn() -> RefreshRecord,
    save_record: fn(RefreshRecord) -> Nil,
    fetch_metadata: fn() -> Result(BulkMetadata, String),
    import_cards: fn(String) -> Result(Nil, String),
  )
}

pub type RefreshCatalogError {
  RefreshCatalogError(message: String)
}
