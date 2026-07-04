import collection/application/queries/latest_status/ports
import collection/infrastructure/daos/collection_dao
import gleam/option.{None, Some}
import gleam/result

pub fn new() -> ports.LatestImportStatusPort {
  ports.LatestImportStatusPort(latest: fn() {
    use run <- result.try(collection_dao.latest())
    case run {
      None -> Ok(None)
      Some(#(id, source_name, status, row_count)) ->
        Ok(
          Some(ports.ImportRunReadModel(
            id: id,
            source_name: source_name,
            status: status,
            row_count: row_count,
          )),
        )
    }
  })
}
