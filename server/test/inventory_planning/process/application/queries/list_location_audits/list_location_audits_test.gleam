import gleam/time/timestamp
import inventory_planning/application/queries/list_location_audits/handler
import inventory_planning/domain/location_audit.{AuditRecord}
import inventory_planning/domain/location_ref.{Cascade}

pub fn returns_each_locations_latest_audit_test() {
  let older = AuditRecord(Cascade("Binder"), timestamp.from_unix_seconds(1))
  let newer = AuditRecord(Cascade("Binder"), timestamp.from_unix_seconds(2))

  assert handler.execute(handler.ListLocationAuditsQuery, fn() {
      Ok([newer, older])
    })
    == Ok([newer])
}

pub fn propagates_a_read_error_test() {
  assert handler.execute(handler.ListLocationAuditsQuery, fn() {
      Error("db unavailable")
    })
    == Error("db unavailable")
}
