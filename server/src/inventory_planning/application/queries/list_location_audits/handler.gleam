import gleam/result
import inventory_planning/application/queries/list_location_audits/ports
import inventory_planning/domain/location_audit.{type AuditRecord}

pub type ListLocationAuditsQuery {
  ListLocationAuditsQuery
}

/// When each audited location was last audited; never-audited ones are
/// absent.
pub fn execute(
  _query: ListLocationAuditsQuery,
  port: ports.ListLocationAuditsPort,
) -> Result(List(AuditRecord), String) {
  port() |> result.map(location_audit.latest_per_location)
}
