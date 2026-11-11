import gleam/dynamic/decode
import shared/infrastructure/stores/sqlite_store
import sqlight

pub type LocationAuditRow {
  LocationAuditRow(
    // "cascade" or "managed", as in placed_cards: `location` is a cascade
    // location's name or a managed location's id accordingly.
    location_kind: String,
    location: String,
    // RFC 3339, UTC.
    completed_at: String,
  )
}

fn location_audit_row_decoder() -> decode.Decoder(LocationAuditRow) {
  use location_kind <- decode.field(0, decode.string)
  use location <- decode.field(1, decode.string)
  use completed_at <- decode.field(2, decode.string)
  decode.success(LocationAuditRow(location_kind:, location:, completed_at:))
}

pub fn list() -> Result(List(LocationAuditRow), String) {
  sqlite_store.query(
    "SELECT location_kind, location, completed_at FROM location_audits "
      <> "ORDER BY location_kind, location, completed_at;",
    [],
    location_audit_row_decoder(),
  )
}

/// The insert as a statement, for composing with the audit's ledger writes in
/// one `sqlite_store.exec_all_atomically`.
pub fn insert_statement(
  row: LocationAuditRow,
) -> #(String, List(sqlight.Value)) {
  #(
    "INSERT INTO location_audits (location_kind, location, completed_at) "
      <> "VALUES (?, ?, ?);",
    [
      sqlight.text(row.location_kind),
      sqlight.text(row.location),
      sqlight.text(row.completed_at),
    ],
  )
}
