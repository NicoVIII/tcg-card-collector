import inventory_planning/domain/location_audit.{type AuditRecord}

pub type ListLocationAuditsPort =
  fn() -> Result(List(AuditRecord), String)
