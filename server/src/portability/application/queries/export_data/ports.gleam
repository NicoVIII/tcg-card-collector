import gleam/time/calendar.{type Date}
import portability/domain/export_document.{
  type AuditEntry, type BulkSpec, type CollectionEntry,
  type ManagedLocationEntry, type MemberEntry, type PlacedEntry, type Rule,
}

pub type ListCollectionEntriesPort =
  fn() -> Result(List(CollectionEntry), String)

pub type ListTargetSetsPort =
  fn() -> Result(List(String), String)

pub type ListRulesPort =
  fn() -> Result(List(Rule), String)

pub type GetBulkSpecPort =
  fn() -> Result(BulkSpec, String)

pub type ListManagedLocationsPort =
  fn() -> Result(#(List(ManagedLocationEntry), List(MemberEntry)), String)

pub type ListPlacedPort =
  fn() -> Result(List(PlacedEntry), String)

pub type ListAuditsPort =
  fn() -> Result(List(AuditEntry), String)

pub type TodayPort =
  fn() -> Date

pub type ExportDataPorts {
  ExportDataPorts(
    list_collection_entries: ListCollectionEntriesPort,
    list_target_sets: ListTargetSetsPort,
    list_rules: ListRulesPort,
    get_bulk_spec: GetBulkSpecPort,
    list_managed_locations: ListManagedLocationsPort,
    list_placed: ListPlacedPort,
    list_audits: ListAuditsPort,
    today: TodayPort,
  )
}
