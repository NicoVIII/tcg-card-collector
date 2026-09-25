import gleam/result
import portability/application/queries/export_data/ports
import portability/domain/export_document.{type ExportDocument, InsightsSection}

pub type ExportDataQuery {
  ExportDataQuery
}

pub fn execute(
  _query: ExportDataQuery,
  ports: ports.ExportDataPorts,
) -> Result(ExportDocument, String) {
  use collection <- result.try(ports.list_collection_entries())
  use target_sets <- result.try(ports.list_target_sets())
  Ok(export_document.new(
    ports.today(),
    collection,
    InsightsSection(target_sets:),
  ))
}
