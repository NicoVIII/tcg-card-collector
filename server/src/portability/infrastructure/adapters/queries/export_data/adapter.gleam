import collection/driver/gleam/collection_api
import gleam/list
import gleam/result
import gleam/time/calendar
import gleam/time/timestamp
import portability/application/queries/export_data/ports
import portability/domain/export_document

pub fn new() -> ports.ExportDataPorts {
  ports.ExportDataPorts(
    list_collection_entries: list_collection_entries_adapter(),
    today: today_adapter(),
  )
}

fn list_collection_entries_adapter() -> ports.ListCollectionEntriesPort {
  fn() {
    use copies <- result.try(collection_api.list_copies())
    Ok(
      list.map(copies, fn(copy) {
        export_document.CollectionEntry(key: copy.key, quantity: copy.quantity)
      }),
    )
  }
}

fn today_adapter() -> ports.TodayPort {
  fn() {
    let #(date, _time) =
      timestamp.to_calendar(timestamp.system_time(), calendar.utc_offset)
    date
  }
}
