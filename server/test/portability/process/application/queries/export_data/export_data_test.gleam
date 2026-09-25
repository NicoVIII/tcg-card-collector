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

fn empty_bulk_spec() -> export_document.BulkSpec {
  export_document.BulkSpec(location: "Bulk", sort_keys: "")
}

// Happy-path fakes for every read, overridable per test — a test that cares
// about one read only has to override that one.
fn build_ports(
  list_collection_entries list_collection_entries: fn() ->
    Result(List(export_document.CollectionEntry), String),
  list_target_sets list_target_sets: fn() -> Result(List(String), String),
) -> ports.ExportDataPorts {
  ports.ExportDataPorts(
    list_collection_entries:,
    list_target_sets:,
    list_rules: fn() { Ok([]) },
    get_bulk_spec: fn() { Ok(empty_bulk_spec()) },
    list_placed: fn() { Ok([]) },
    today: fn() { a_date() },
  )
}

pub fn document_carries_the_read_date_entries_and_target_sets_test() {
  let entries = [an_entry("mh2", "17", 2)]
  let ports =
    build_ports(
      list_collection_entries: fn() { Ok(entries) },
      list_target_sets: fn() { Ok(["neo"]) },
    )

  let assert Ok(document) = handler.execute(handler.ExportDataQuery, ports)

  assert document.exported_on == a_date()
  assert document.collection == entries
  assert document.insights
    == export_document.InsightsSection(target_sets: [
      "neo",
    ])
}

pub fn empty_sections_yield_an_empty_document_test() {
  let ports =
    build_ports(
      list_collection_entries: fn() { Ok([]) },
      list_target_sets: fn() { Ok([]) },
    )

  let assert Ok(document) = handler.execute(handler.ExportDataQuery, ports)

  assert document.collection == []
  assert document.insights == export_document.InsightsSection(target_sets: [])
  assert document.inventory_planning.rules == []
  assert document.inventory_planning.bulk == empty_bulk_spec()
  assert document.inventory_planning.placed == []
}

pub fn a_collection_read_failure_propagates_as_error_test() {
  let ports =
    build_ports(
      list_collection_entries: fn() { Error("collection unreadable") },
      list_target_sets: fn() {
        panic as "must not read target sets once the collection read failed"
      },
    )

  let result = handler.execute(handler.ExportDataQuery, ports)

  assert result == Error("collection unreadable")
}

pub fn a_target_sets_read_failure_propagates_as_error_test() {
  let ports =
    build_ports(
      list_collection_entries: fn() { Ok([]) },
      list_target_sets: fn() { Error("target sets unreadable") },
    )

  let result = handler.execute(handler.ExportDataQuery, ports)

  assert result == Error("target sets unreadable")
}

pub fn an_inventory_planning_read_failure_propagates_as_error_test() {
  let ports =
    ports.ExportDataPorts(
      ..build_ports(
        list_collection_entries: fn() { Ok([]) },
        list_target_sets: fn() { Ok([]) },
      ),
      list_rules: fn() { Error("rules unreadable") },
    )

  let result = handler.execute(handler.ExportDataQuery, ports)

  assert result == Error("rules unreadable")
}
