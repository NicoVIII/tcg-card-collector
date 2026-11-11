import gleam/list
import gleam/result
import gleam/time/timestamp
import inventory_planning/application/queries/list_location_audits/ports
import inventory_planning/domain/location_audit.{type AuditRecord, AuditRecord}
import inventory_planning/domain/location_ref
import inventory_planning/infrastructure/daos/location_audits_dao

fn parse_row(
  row: location_audits_dao.LocationAuditRow,
) -> Result(AuditRecord, String) {
  case
    location_ref.new(kind: row.location_kind, key: row.location),
    timestamp.parse_rfc3339(row.completed_at)
  {
    Ok(location), Ok(completed_at) -> Ok(AuditRecord(location:, completed_at:))
    _, _ -> Error("unparseable location_audits row")
  }
}

fn list_audits() -> Result(List(AuditRecord), String) {
  use rows <- result.try(location_audits_dao.list())
  list.try_map(rows, parse_row)
}

pub fn new() -> ports.ListLocationAuditsPort {
  list_audits
}
