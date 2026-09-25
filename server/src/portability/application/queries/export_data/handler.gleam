import gleam/result
import portability/application/queries/export_data/ports
import portability/domain/export_document.{
  type ExportDocument, InsightsSection, InventoryPlanningSection,
}

pub type ExportDataQuery {
  ExportDataQuery
}

pub fn execute(
  _query: ExportDataQuery,
  ports: ports.ExportDataPorts,
) -> Result(ExportDocument, String) {
  use collection <- result.try(ports.list_collection_entries())
  use target_sets <- result.try(ports.list_target_sets())
  use rules <- result.try(ports.list_rules())
  use bulk <- result.try(ports.get_bulk_spec())
  use placed <- result.try(ports.list_placed())
  Ok(export_document.new(
    ports.today(),
    collection,
    InsightsSection(target_sets:),
    InventoryPlanningSection(rules:, bulk:, placed:),
  ))
}
