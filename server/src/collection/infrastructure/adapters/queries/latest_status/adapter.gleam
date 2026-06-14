import collection/application/queries/latest_status/ports
import collection/infrastructure/stores/collection_store
import gleam/option.{None, Some}

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
