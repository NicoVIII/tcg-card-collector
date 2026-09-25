import gleam/option
import portability/application/queries/preview_import/ports
import portability/domain/import_document.{
  type ImportDocument, type LedgerExcess, type RejectedEntry, type SectionResult,
}

pub type PreviewImportQuery {
  PreviewImportQuery(document: ImportDocument)
}

pub type ImportPreview {
  ImportPreview(
    sections: List(SectionResult),
    rejected: List(RejectedEntry),
    excess: List(LedgerExcess),
  )
}

/// Resolves the one validation pass `export_file.parse` couldn't do alone
/// (rules and the bulk spec need Inventory Planning's parsers), then
/// reports what an import would do — without writing anything.
pub fn execute(
  query: PreviewImportQuery,
  ports: ports.PreviewImportPorts,
) -> ImportPreview {
  let resolved =
    import_document.resolve_deep_sections(
      query.document,
      ports.check_rule,
      ports.check_sort_keys,
    )
  ImportPreview(
    sections: import_document.section_results(resolved),
    rejected: resolved.rejected,
    excess: import_document.ledger_excess(
      resolved.collection,
      option.unwrap(resolved.placed, []),
    ),
  )
}
