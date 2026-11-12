import gleam/option
import gleam/result
import portability/application/queries/preview_import/ports
import portability/domain/import_document.{
  type ImportDocument, type LedgerPrune, type ManagedShortfall,
  type RejectedEntry, type SectionResult, DeepCheckers,
}

pub type PreviewImportQuery {
  PreviewImportQuery(document: ImportDocument)
}

pub type ImportPreview {
  ImportPreview(
    sections: List(SectionResult),
    rejected: List(RejectedEntry),
    pruned: List(LedgerPrune),
    shortfall: List(ManagedShortfall),
  )
}

/// Resolves the one validation pass `export_file.parse` couldn't do alone
/// (rules, the bulk spec, and managed-location kinds need Inventory
/// Planning's parsers), then reports what an import would do — without
/// writing anything. Fails only when the current ledger can't be read.
pub fn execute(
  query: PreviewImportQuery,
  ports: ports.PreviewImportPorts,
) -> Result(ImportPreview, String) {
  let resolved =
    import_document.resolve_deep_sections(
      query.document,
      DeepCheckers(
        check_rule: ports.check_rule,
        check_bulk_spec: ports.check_bulk_spec,
        check_managed_kind: ports.check_managed_kind,
      ),
    )
  use pruned <- result.map(ports.predict_prune(
    resolved.collection,
    import_document.managed_with_members(resolved),
    resolved.placed,
  ))
  ImportPreview(
    sections: import_document.section_results(resolved),
    rejected: resolved.rejected,
    pruned:,
    shortfall: import_document.managed_shortfall(
      resolved.collection,
      option.unwrap(resolved.managed_locations, []),
      option.unwrap(resolved.members, []),
    ),
  )
}
