import gleam/list
import portability/application/commands/import_data/ports as import_data_ports
import portability/domain/export_document.{type ExportDocument}
import portability/domain/import_document.{
  type DocumentError, type ImportDocument, type SectionResult,
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

/// The excess ledger list stays empty until #119 adds the
/// inventory_planning section — there is no ledger to check yet.
pub fn map_import_preview(
  document: ImportDocument,
) -> portability_queries.ImportPreview {
  portability_queries.import_preview_new(
    sections: list.map(
      import_document.section_results(document),
      map_section_result,
    ),
    rejected: list.map(document.rejected, map_rejected_entry),
    excess: [],
  )
}

pub fn map_import_data_result(
  result: Result(List(SectionResult), import_data_ports.ImportDataError),
) -> Result(portability_commands.ImportedData, service.ServiceError) {
  case result {
    Ok(sections) ->
      Ok(
        portability_commands.imported_data_new(sections: list.map(
          sections,
          map_command_section_result,
        )),
      )
    Error(error) ->
      Error(helpers.service_error(error_presentation.import_data(error)))
  }
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
