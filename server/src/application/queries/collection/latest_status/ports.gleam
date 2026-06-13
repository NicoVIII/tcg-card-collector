import domain/collection/import_status.{type ImportStatus}
import gleam/option.{type Option}

pub type ImportRunReadModel {
  ImportRunReadModel(
    id: String,
    source_name: String,
    status: ImportStatus,
    row_count: Int,
  )
}

pub type LatestImportStatusPort {
  LatestImportStatusPort(latest: fn() -> Option(ImportRunReadModel))
}
