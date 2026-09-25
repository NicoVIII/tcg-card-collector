import gleam/result
import portability/application/queries/export_data/ports
import portability/domain/export_document.{type ExportDocument}

pub type ExportDataQuery {
  ExportDataQuery
}

pub fn execute(
  _query: ExportDataQuery,
  ports: ports.ExportDataPorts,
) -> Result(ExportDocument, String) {
  use collection <- result.try(ports.list_collection_entries())
  Ok(export_document.new(ports.today(), collection))
}
