import application/queries/collection_import/latest_status/ports
import gleam/option.{None, Some}
import infrastructure/stores/collection_import/collection_import_store

pub fn new() -> ports.LatestImportStatusPort {
  ports.LatestImportStatusPort(latest: fn() {
    case collection_import_store.latest() {
      None -> None
      Some(#(id, source_name, status, row_count)) ->
        Some(ports.ImportRunReadModel(
          id: id,
          source_name: source_name,
          status: status,
          row_count: row_count,
        ))
    }
  })
}
