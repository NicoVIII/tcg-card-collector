import application/collection_import/ports
import application/collection_import/service
import gleam/list
import gleam/option.{type Option, None, Some}

pub type ImportCollectionRow {
  ImportCollectionRow(
    card_name: String,
    set_code: String,
    collector_number: String,
    quantity: Int,
  )
}

pub type ImportCollectionRequest {
  ImportCollectionRequest(
    import_run_id: String,
    source_name: String,
    source_checksum: String,
    row_count: Int,
    rows: List(ImportCollectionRow),
  )
}

pub type ImportCollectionResponse {
  Accepted
  Rejected
}

pub type LatestImportStatusResponse {
  ImportStatusFound(ports.ImportRunReadModel)
  ImportStatusNotFound
}

pub fn import_collection(
  repository: ports.CollectionImportRepository,
  request: ImportCollectionRequest,
) -> ImportCollectionResponse {
  let ImportCollectionRequest(
    import_run_id: import_run_id,
    source_name: source_name,
    row_count: row_count,
    rows: rows,
    ..,
  ) = request

  let actual_row_count = list.length(rows)

  persist_run(
    repository,
    import_run_id,
    source_name,
    "pending",
    actual_row_count,
  )
  persist_run(
    repository,
    import_run_id,
    source_name,
    "running",
    actual_row_count,
  )

  case row_count == actual_row_count {
    True -> {
      persist_run(
        repository,
        import_run_id,
        source_name,
        "succeeded",
        actual_row_count,
      )
      Accepted
    }
    False -> {
      persist_run(
        repository,
        import_run_id,
        source_name,
        "failed",
        actual_row_count,
      )
      Rejected
    }
  }
}

fn persist_run(
  repository: ports.CollectionImportRepository,
  import_run_id: String,
  source_name: String,
  status: String,
  row_count: Int,
) -> Nil {
  service.import_collection(
    repository,
    ports.ImportRunWriteModel(
      id: import_run_id,
      source_name: source_name,
      status: status,
      row_count: row_count,
    ),
  )
}

pub fn get_latest_import_status(
  repository: ports.CollectionImportRepository,
) -> LatestImportStatusResponse {
  let status: Option(ports.ImportRunReadModel) =
    service.latest_import_status(repository)

  case status {
    Some(run) -> ImportStatusFound(run)
    None -> ImportStatusNotFound
  }
}
