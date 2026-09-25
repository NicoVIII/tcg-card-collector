import gleam/time/calendar.{type Date}
import portability/domain/export_document.{type CollectionEntry}

pub type ListCollectionEntriesPort =
  fn() -> Result(List(CollectionEntry), String)

pub type TodayPort =
  fn() -> Date

pub type ExportDataPorts {
  ExportDataPorts(
    list_collection_entries: ListCollectionEntriesPort,
    today: TodayPort,
  )
}
