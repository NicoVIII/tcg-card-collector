import application/queries/collection_import/latest_status/ports
import gleam/option.{type Option}

pub type LatestImportStatusQuery {
  LatestImportStatusQuery
}

pub fn execute(
  _query: LatestImportStatusQuery,
  port: ports.LatestImportStatusPort,
) -> Option(ports.ImportRunReadModel) {
  port.latest()
}
