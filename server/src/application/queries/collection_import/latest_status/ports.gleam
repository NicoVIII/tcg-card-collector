import gleam/option.{type Option}

pub type ImportRunReadModel {
  ImportRunReadModel(
    id: String,
    source_name: String,
    status: String,
    row_count: Int,
  )
}

pub type LatestImportStatusPort {
  LatestImportStatusPort(latest: fn() -> Option(ImportRunReadModel))
}
