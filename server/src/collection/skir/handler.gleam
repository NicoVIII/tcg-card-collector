import collection/application/commands/import_collection/handler as import_collection_handler
import collection/application/commands/import_collection/ports as import_collection_ports
import collection/application/queries/latest_status/handler as latest_status_handler
import collection/application/queries/latest_status/ports as latest_status_ports
import collection/domain/import_status
import gleam/list
import gleam/option.{None, Some}

pub type ImportCollectionRow {
  ImportCollectionRow(set_code: String, collector_number: String, quantity: Int)
}

pub type ImportCollectionResponse {
  Accepted
  Rejected
}

pub type LatestImportStatusResponse {
  ImportStatusFound(latest_status_ports.ImportRunReadModel)
  ImportStatusNotFound
}

pub fn import_collection(
  port: import_collection_ports.ImportCollectionPort,
  import_run_id: String,
  source_name: String,
  source_checksum: String,
  row_count: Int,
  rows: List(ImportCollectionRow),
) -> ImportCollectionResponse {
  let command =
    import_collection_handler.ImportCollectionCommand(
      import_run_id: import_run_id,
      source_name: source_name,
      source_checksum: source_checksum,
      row_count: row_count,
      rows: list.map(rows, fn(row) {
        let ImportCollectionRow(
          set_code: set_code,
          collector_number: collector_number,
          quantity: quantity,
        ) = row
        import_collection_ports.ImportCollectionRow(
          set_code: set_code,
          collector_number: collector_number,
          quantity: quantity,
        )
      }),
    )
  case import_collection_handler.execute(command, port) {
    Ok(_) -> Accepted
    Error(_) -> Rejected
  }
}

pub fn get_latest_import_status(
  port: latest_status_ports.LatestImportStatusPort,
) -> LatestImportStatusResponse {
  case
    latest_status_handler.execute(
      latest_status_handler.LatestImportStatusQuery,
      port,
    )
  {
    None -> ImportStatusNotFound
    Some(run) -> ImportStatusFound(run)
  }
}

pub fn status_to_string(status: import_status.ImportStatus) -> String {
  import_status.to_string(status)
}
