import portability/application/commands/import_data/handler
import portability/application/commands/import_data/ports
import portability/domain/export_document
import portability/domain/import_document
import shared/domain/copy_key

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

pub fn an_empty_document_is_rejected_without_replacing_the_collection_test() {
  let document = import_document.ImportDocument(collection: [], rejected: [])
  let import_ports =
    ports.ImportDataPorts(replace_collection: fn(_) {
      panic as "must not replace the collection for an empty document"
    })

  assert handler.execute(handler.ImportDataCommand(document:), import_ports)
    == Error(ports.NothingToImport)
}

pub fn valid_entries_replace_the_collection_and_their_count_is_returned_test() {
  let entries = [an_entry(2), an_entry(3)]
  let document =
    import_document.ImportDocument(collection: entries, rejected: [])
  let import_ports =
    ports.ImportDataPorts(replace_collection: fn(received) {
      assert received == entries
      Ok(Nil)
    })

  assert handler.execute(handler.ImportDataCommand(document:), import_ports)
    == Ok(2)
}

pub fn a_persistence_failure_propagates_test() {
  let document =
    import_document.ImportDocument(collection: [an_entry(1)], rejected: [])
  let import_ports =
    ports.ImportDataPorts(replace_collection: fn(_) { Error("db down") })

  assert handler.execute(handler.ImportDataCommand(document:), import_ports)
    == Error(ports.PersistenceFailed("db down"))
}
