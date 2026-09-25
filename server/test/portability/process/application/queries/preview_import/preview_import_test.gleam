import gleam/option.{None, Some}
import portability/application/queries/preview_import/handler
import portability/application/queries/preview_import/ports
import portability/domain/export_document.{
  BulkSpec, CollectionEntry, PlacedEntry, Rule,
}
import portability/domain/import_document.{
  type ImportDocument, BulkSection, CollectionSection, ImportDocument,
  LedgerExcess, RejectedEntry, RulesSection, SectionResult,
}
import shared/domain/copy_key

fn happy_ports() -> ports.PreviewImportPorts {
  ports.PreviewImportPorts(
    check_rule: fn(_rule) { Ok(Nil) },
    check_sort_keys: fn(_raw) { Ok(Nil) },
  )
}

fn empty_document() -> ImportDocument {
  ImportDocument(
    collection: [],
    rejected: [],
    target_sets: None,
    rules: None,
    bulk: None,
    placed: None,
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

  let preview =
    handler.execute(handler.PreviewImportQuery(document:), happy_ports())

  assert preview.sections == [SectionResult(CollectionSection, 1)]
  assert preview.rejected == []
  assert preview.excess == []
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

  let preview =
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

  let preview =
    handler.execute(handler.PreviewImportQuery(document:), happy_ports())

  assert preview.sections
    == [SectionResult(CollectionSection, 0), SectionResult(BulkSection, 1)]
}

pub fn placed_copies_beyond_what_is_owned_are_reported_as_excess_test() {
  let assert Ok(key) =
    copy_key.new(
      set_code: "mh2",
      collector_number: "17",
      finish: "foil",
      language: "en",
    )
  let document =
    ImportDocument(
      ..empty_document(),
      collection: [CollectionEntry(key:, quantity: 1)],
      placed: Some([PlacedEntry(key:, location: "Box A", quantity: 3)]),
    )

  let preview =
    handler.execute(handler.PreviewImportQuery(document:), happy_ports())

  assert preview.excess
    == [LedgerExcess(identity: "mh2 17 foil en", placed: 3, owned: 1)]
}
