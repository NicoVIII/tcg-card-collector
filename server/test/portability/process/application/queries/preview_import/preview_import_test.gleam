import gleam/option.{None, Some}
import portability/application/queries/preview_import/handler
import portability/application/queries/preview_import/ports
import portability/domain/export_document.{
  BulkSpec, CollectionEntry, PlacedEntry, Rule,
}
import portability/domain/import_document.{
  type ImportDocument, BulkSection, CollectionSection, ImportDocument,
  LedgerPrune, RejectedEntry, RulesSection, SectionResult,
}
import shared/domain/copy_key

fn happy_ports() -> ports.PreviewImportPorts {
  ports.PreviewImportPorts(
    check_rule: fn(_rule) { Ok(Nil) },
    check_bulk_spec: fn(_raw) { Ok(Nil) },
    check_managed_kind: fn(_kind) { Ok(Nil) },
    predict_prune: fn(_collection, _managed, _placed) { Ok([]) },
    clears_audit_history: fn(restores_audits, replaces_ledger) {
      !restores_audits && replaces_ledger
    },
  )
}

fn empty_document() -> ImportDocument {
  ImportDocument(
    collection: [],
    rejected: [],
    target_sets: None,
    rules: None,
    bulk: None,
    managed_locations: None,
    members: None,
    placed: None,
    audits: None,
  )
}

pub fn a_document_with_only_a_collection_previews_one_section_test() {
  let assert Ok(key) =
    copy_key.new(
      set_code: "mh2",
      collector_number: "17",
      finish: "foil",
      language: "en",
    )
  let document =
    ImportDocument(..empty_document(), collection: [
      CollectionEntry(key:, quantity: 2),
    ])

  let assert Ok(preview) =
    handler.execute(handler.PreviewImportQuery(document:), happy_ports())

  assert preview.sections == [SectionResult(CollectionSection, 1)]
  assert preview.rejected == []
  assert preview.pruned == []
}

pub fn a_rule_the_checker_rejects_is_reported_and_not_counted_test() {
  let document =
    ImportDocument(
      ..empty_document(),
      rules: Some([
        Rule(
          location: "Binder A",
          expression: "bogus",
          selector: "all",
          sort_keys: "",
        ),
      ]),
    )
  let import_ports =
    ports.PreviewImportPorts(..happy_ports(), check_rule: fn(_rule) {
      Error("invalid match expression")
    })

  let assert Ok(preview) =
    handler.execute(handler.PreviewImportQuery(document:), import_ports)

  assert preview.sections
    == [SectionResult(CollectionSection, 0), SectionResult(RulesSection, 0)]
  assert preview.rejected
    == [
      RejectedEntry(
        section: RulesSection,
        position: 1,
        identity: "Binder A",
        reason: "invalid match expression",
      ),
    ]
}

pub fn a_valid_bulk_spec_is_counted_as_one_section_test() {
  let document =
    ImportDocument(
      ..empty_document(),
      bulk: Some(BulkSpec(location: "Bulk", sort_keys: "name")),
    )

  let assert Ok(preview) =
    handler.execute(handler.PreviewImportQuery(document:), happy_ports())

  assert preview.sections
    == [SectionResult(CollectionSection, 0), SectionResult(BulkSection, 1)]
}

pub fn the_ledger_rows_the_import_would_prune_are_reported_test() {
  // arrange
  let assert Ok(key) =
    copy_key.new(
      set_code: "mh2",
      collector_number: "17",
      finish: "foil",
      language: "en",
    )
  let collection = [CollectionEntry(key:, quantity: 1)]
  let placed = [
    PlacedEntry(
      key:,
      location: export_document.InLocation("Box A"),
      quantity: 3,
    ),
  ]
  let document =
    ImportDocument(..empty_document(), collection:, placed: Some(placed))
  let prune =
    LedgerPrune(
      identity: "mh2 17 foil en",
      location: export_document.InLocation("Box A"),
      quantity: 2,
    )
  let import_ports =
    ports.PreviewImportPorts(..happy_ports(), predict_prune: fn(c, m, p) {
      case c == collection && m == None && p == Some(placed) {
        True -> Ok([prune])
        False -> Error("asked about other sections")
      }
    })

  // act
  let result =
    handler.execute(handler.PreviewImportQuery(document:), import_ports)

  // assert
  let assert Ok(preview) = result
  assert preview.pruned == [prune]
}

pub fn a_ledger_that_cannot_be_read_fails_the_preview_test() {
  // arrange
  let document = empty_document()
  let import_ports =
    ports.PreviewImportPorts(..happy_ports(), predict_prune: fn(_, _, _) {
      Error("db down")
    })

  // act
  let result =
    handler.execute(handler.PreviewImportQuery(document:), import_ports)

  // assert
  assert result == Error("db down")
}

pub fn a_ledger_without_audits_says_the_history_is_cleared_test() {
  let document = ImportDocument(..empty_document(), placed: Some([]))

  let assert Ok(preview) =
    handler.execute(handler.PreviewImportQuery(document:), happy_ports())

  assert preview.clears_audit_history
}

pub fn a_ledger_with_its_audits_keeps_the_history_test() {
  let document =
    ImportDocument(..empty_document(), placed: Some([]), audits: Some([]))

  let assert Ok(preview) =
    handler.execute(handler.PreviewImportQuery(document:), happy_ports())

  assert !preview.clears_audit_history
}
