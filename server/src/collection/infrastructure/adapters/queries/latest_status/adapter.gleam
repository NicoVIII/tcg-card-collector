import collection/application/queries/latest_status/ports
import collection/infrastructure/daos/collection_dao
import gleam/option.{None, Some}

pub fn new() -> ports.LatestImportStatusPort {
  ports.LatestImportStatusPort(latest: fn() {
    case collection_dao.latest() {
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
