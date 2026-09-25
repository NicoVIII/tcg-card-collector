import gleam/option.{None, Some}
import portability/application/commands/import_data/handler
import portability/application/commands/import_data/ports
import portability/domain/export_document
import portability/domain/import_document.{
  CollectionSection, SectionResult, TargetSetsSection,
}
import shared/domain/copy_key
import support/ref

fn an_entry(quantity: Int) -> export_document.CollectionEntry {
  let assert Ok(key) =
    copy_key.new(
      set_code: "mh2",
      collector_number: "17",
      finish: "nonfoil",
      language: "en",
    )
  export_document.CollectionEntry(key:, quantity:)
}

fn build_ports(
  written written: ref.Ref(List(import_document.Section)),
  replace_target_sets_result replace_target_sets_result: Result(Nil, String),
  replace_collection_result replace_collection_result: Result(Nil, String),
) -> ports.ImportDataPorts {
  ports.ImportDataPorts(
    replace_target_sets: fn(_codes) {
      case replace_target_sets_result {
        Ok(Nil) -> {
          ref.set(written, [TargetSetsSection, ..ref.get(written)])
          Ok(Nil)
        }
        Error(reason) -> Error(reason)
      }
    },
    replace_collection: fn(_entries) {
      case replace_collection_result {
        Ok(Nil) -> {
          ref.set(written, [CollectionSection, ..ref.get(written)])
          Ok(Nil)
        }
        Error(reason) -> Error(reason)
      }
    },
  )
}

pub fn an_empty_document_is_rejected_without_writing_any_section_test() {
  let written = ref.new([])
  let document =
    import_document.ImportDocument(
      collection: [],
      rejected: [],
      target_sets: Some(["neo"]),
    )
  let import_ports =
    build_ports(
      written:,
      replace_target_sets_result: Ok(Nil),
      replace_collection_result: Ok(Nil),
    )

  let result =
    handler.execute(handler.ImportDataCommand(document:), import_ports)

  assert result == Error(ports.NothingToImport)
  assert ref.get(written) == []
}

pub fn valid_entries_replace_the_collection_and_the_section_counts_are_returned_test() {
  let written = ref.new([])
  let entries = [an_entry(2), an_entry(3)]
  let document =
    import_document.ImportDocument(
      collection: entries,
      rejected: [],
      target_sets: None,
    )
  let import_ports =
    build_ports(
      written:,
      replace_target_sets_result: Ok(Nil),
      replace_collection_result: Ok(Nil),
    )

  let result =
    handler.execute(handler.ImportDataCommand(document:), import_ports)

  assert result == Ok([SectionResult(CollectionSection, 2)])
  assert ref.get(written) == [CollectionSection]
}

pub fn a_present_target_sets_section_is_written_before_the_collection_test() {
  let written = ref.new([])
  let document =
    import_document.ImportDocument(
      collection: [an_entry(1)],
      rejected: [],
      target_sets: Some(["neo", "2xm"]),
    )
  let import_ports =
    build_ports(
      written:,
      replace_target_sets_result: Ok(Nil),
      replace_collection_result: Ok(Nil),
    )

  let result =
    handler.execute(handler.ImportDataCommand(document:), import_ports)

  assert result
    == Ok([
      SectionResult(CollectionSection, 1),
      SectionResult(TargetSetsSection, 2),
    ])
  assert ref.get(written) == [CollectionSection, TargetSetsSection]
}

pub fn a_persistence_failure_before_any_section_writes_is_reported_plainly_test() {
  let written = ref.new([])
  let document =
    import_document.ImportDocument(
      collection: [an_entry(1)],
      rejected: [],
      target_sets: None,
    )
  let import_ports =
    build_ports(
      written:,
      replace_target_sets_result: Ok(Nil),
      replace_collection_result: Error("db down"),
    )

  let result =
    handler.execute(handler.ImportDataCommand(document:), import_ports)

  assert result == Error(ports.PersistenceFailed("db down"))
}

pub fn a_failure_after_an_earlier_section_wrote_names_what_was_written_test() {
  let written = ref.new([])
  let document =
    import_document.ImportDocument(
      collection: [an_entry(1)],
      rejected: [],
      target_sets: Some(["neo"]),
    )
  let import_ports =
    build_ports(
      written:,
      replace_target_sets_result: Ok(Nil),
      replace_collection_result: Error("db down"),
    )

  let result =
    handler.execute(handler.ImportDataCommand(document:), import_ports)

  assert result
    == Error(ports.PartiallyWritten(
      written: [TargetSetsSection],
      reason: "db down",
    ))
  assert ref.get(written) == [TargetSetsSection]
}
