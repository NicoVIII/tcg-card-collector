import collection/application/queries/latest_status/ports
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
