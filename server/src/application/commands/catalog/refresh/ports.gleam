pub type BulkMetadata {
  BulkMetadata(updated_at: String, download_uri: String)
}

pub type RefreshCatalogPort {
  RefreshCatalogPort(
    is_probe_due: fn() -> Bool,
    current_upstream_updated_at: fn() -> String,
    fetch_metadata: fn() -> Result(BulkMetadata, String),
    import_cards: fn(String) -> Result(Nil, String),
    record_succeeded: fn(String) -> Nil,
    record_skipped: fn(String) -> Nil,
    record_failed: fn(String) -> Nil,
  )
}

pub type RefreshCatalogError {
  RefreshCatalogError(message: String)
}
