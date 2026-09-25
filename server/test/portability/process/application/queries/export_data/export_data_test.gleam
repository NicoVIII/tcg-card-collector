import gleam/time/calendar
import portability/application/queries/export_data/handler
import portability/application/queries/export_data/ports
import portability/domain/export_document
import shared/domain/copy_key

fn a_date() -> calendar.Date {
  calendar.Date(2026, calendar.September, 25)
}

fn an_entry(
  set_code: String,
  collector_number: String,
  quantity: Int,
) -> export_document.CollectionEntry {
  let assert Ok(key) =
    copy_key.new(
      set_code:,
      collector_number:,
      finish: "nonfoil",
      language: "en",
    )
  export_document.CollectionEntry(key:, quantity:)
}

pub fn document_carries_the_read_date_and_entries_test() {
  let entries = [an_entry("mh2", "17", 2)]
  let ports =
    ports.ExportDataPorts(
      list_collection_entries: fn() { Ok(entries) },
      today: fn() { a_date() },
    )

  let assert Ok(document) = handler.execute(handler.ExportDataQuery, ports)

  assert document.exported_on == a_date()
  assert document.collection == entries
}

pub fn empty_collection_yields_an_empty_document_test() {
  let ports =
    ports.ExportDataPorts(list_collection_entries: fn() { Ok([]) }, today: fn() {
      a_date()
    })

  let assert Ok(document) = handler.execute(handler.ExportDataQuery, ports)

  assert document.collection == []
}

pub fn a_read_failure_propagates_as_error_test() {
  let ports =
    ports.ExportDataPorts(
      list_collection_entries: fn() { Error("collection unreadable") },
      today: fn() { a_date() },
    )

  let result = handler.execute(handler.ExportDataQuery, ports)

  assert result == Error("collection unreadable")
}
