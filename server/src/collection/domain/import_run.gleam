import collection/domain/import_status.{type ImportStatus}

pub type ImportRun {
  ImportRun(
    id: String,
    source_name: String,
    status: ImportStatus,
    row_count: Int,
  )
}
