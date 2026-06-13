import application/queries/collection/latest_status/ports
import gleam/option.{None, Some}
import infrastructure/stores/collection/collection_store

pub fn new() -> ports.LatestImportStatusPort {
  ports.LatestImportStatusPort(latest: fn() {
    case collection_store.latest() {
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
