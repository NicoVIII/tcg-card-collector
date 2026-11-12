import gleam/list
import portability/application/commands/import_data/handler.{type ImportResult} as _
import portability/application/commands/import_data/ports as import_data_ports
import portability/application/queries/preview_import/handler.{
  type ImportPreview,
}
import portability/domain/export_document.{
  type ExportDocument, InLocation, InManagedLocation,
}
import portability/domain/import_document.{
  type DocumentError, type LedgerPrune, type SectionResult,
}
import portability/driver/error_presentation
import portability/driver/export_file
import shared/driver/skir/helpers
import shared/driver/skir/skirout/portability/commands as portability_commands
import shared/driver/skir/skirout/portability/queries as portability_queries
import skir_client/service

pub fn map_export_data(
  document: ExportDocument,
) -> portability_queries.ExportFile {
  portability_queries.export_file_new(
    content: export_file.render(document),
    filename: export_file.filename(document),
  )
}

/// Both PreviewImport and ImportData parse the same file before doing
/// anything else with it, and both surface a parse failure the same way
/// (ADR 0019: import never guesses) — shared here so the two door handlers
/// don't each write their own mapping.
pub fn map_parse_error(error: DocumentError) -> service.ServiceError {
  helpers.service_error(error_presentation.document_error(error))
}

fn map_section_result(
  result: SectionResult,
) -> portability_queries.SectionCount {
  portability_queries.section_count_new(
    section: import_document.section_name(result.section),
    count: result.count,
  )
}

fn map_command_section_result(
  result: SectionResult,
) -> portability_commands.SectionCount {
  portability_commands.section_count_new(
    section: import_document.section_name(result.section),
    count: result.count,
  )
}

fn map_rejected_entry(
  rejected: import_document.RejectedEntry,
) -> portability_queries.RejectedEntry {
  portability_queries.rejected_entry_new(
    section: import_document.section_name(rejected.section),
    identity: rejected.identity,
    position: rejected.position,
    reason: rejected.reason,
  )
}

fn map_managed_shortfall(
  shortfall: import_document.ManagedShortfall,
) -> portability_queries.ManagedShortfall {
  portability_queries.managed_shortfall_new(
    identity: shortfall.identity,
    location_name: shortfall.location_name,
    missing: shortfall.missing,
  )
}

fn map_query_ledger_prune(
  prune: LedgerPrune,
) -> portability_queries.LedgerPrune {
  portability_queries.ledger_prune_new(
    identity: prune.identity,
    location: case prune.location {
      InLocation(name) -> portability_queries.PlacedInCascade(name)
      InManagedLocation(name) -> portability_queries.PlacedInManaged(name)
    },
    quantity: prune.quantity,
  )
}

fn map_command_ledger_prune(
  prune: LedgerPrune,
) -> portability_commands.LedgerPrune {
  portability_commands.ledger_prune_new(
    identity: prune.identity,
    location: case prune.location {
      InLocation(name) -> portability_commands.PlacedInCascade(name)
      InManagedLocation(name) -> portability_commands.PlacedInManaged(name)
    },
    quantity: prune.quantity,
  )
}

pub fn map_import_preview(
  preview: ImportPreview,
) -> portability_queries.ImportPreview {
  portability_queries.import_preview_new(
    sections: list.map(preview.sections, map_section_result),
    rejected: list.map(preview.rejected, map_rejected_entry),
    pruned: list.map(preview.pruned, map_query_ledger_prune),
    shortfall: list.map(preview.shortfall, map_managed_shortfall),
  )
}

pub fn map_import_data_result(
  result: Result(ImportResult, import_data_ports.ImportDataError),
) -> Result(portability_commands.ImportedData, service.ServiceError) {
  case result {
    Ok(imported) ->
      Ok(portability_commands.imported_data_new(
        sections: list.map(imported.sections, map_command_section_result),
        pruned: list.map(imported.pruned, map_command_ledger_prune),
      ))
    Error(error) ->
      Error(helpers.service_error(error_presentation.import_data(error)))
  }
}
