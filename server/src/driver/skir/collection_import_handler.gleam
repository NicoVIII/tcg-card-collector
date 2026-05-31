import application/collection_import/ports
import application/collection_import/service
import gleam/option.{type Option, None, Some}

pub type ImportCollectionRequest {
  ImportCollectionRequest(
    import_run_id: String,
    source_name: String,
    source_checksum: String,
    row_count: Int,
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
    ..,
  ) = request

  service.import_collection(
    repository,
    ports.ImportRunWriteModel(
      id: import_run_id,
      source_name: source_name,
      status: "pending",
      row_count: row_count,
    ),
  )

  Accepted
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
