import collection/driver/gleam/collection_api
import gleam/dict
import gleam/list
import gleam/result
import gleam/time/duration
import gleam/time/timestamp
import inventory_planning/application/commands/complete_location_audit/ports
import inventory_planning/domain/location_audit.{
  type AuditRecord, type LedgerChanges,
}
import inventory_planning/domain/location_ref
import inventory_planning/domain/placed_ledger_reconciliation.{
  type PlacedRow, PlacedRow,
}
import inventory_planning/infrastructure/daos/location_audits_dao
import inventory_planning/infrastructure/daos/managed_locations_dao
import inventory_planning/infrastructure/daos/placed_cards_dao
import shared/domain/copy_key
import shared/infrastructure/stores/sqlite_store

fn parse_placed_row(
  row: placed_cards_dao.PlacedCardRow,
) -> Result(PlacedRow, String) {
  case
    copy_key.new(
      set_code: row.set_code,
      collector_number: row.collector_number,
      finish: row.finish,
      language: row.language,
    ),
    location_ref.new(kind: row.location_kind, key: row.location)
  {
    Ok(key), Ok(location) ->
      Ok(PlacedRow(key:, location:, quantity: row.quantity))
    _, _ -> Error("unparseable placed_cards row")
  }
}

fn list_placed() -> Result(List(PlacedRow), String) {
  use rows <- result.try(placed_cards_dao.list())
  list.try_map(rows, parse_placed_row)
}

fn owned_quantities() -> Result(dict.Dict(copy_key.CopyKey, Int), String) {
  use copies <- result.map(collection_api.list_copies())
  dict.from_list(list.map(copies, fn(copy) { #(copy.key, copy.quantity) }))
}

fn managed_location_ids() -> Result(List(String), String) {
  use locations <- result.map(managed_locations_dao.load_all())
  list.map(locations, fn(location) { location.id })
}

fn to_dao_row(row: PlacedRow) -> placed_cards_dao.PlacedCardRow {
  let PlacedRow(key:, location:, quantity:) = row
  placed_cards_dao.PlacedCardRow(
    set_code: copy_key.set_code_string(key),
    collector_number: copy_key.collector_number_string(key),
    finish: copy_key.finish_string(key),
    language: copy_key.language_string(key),
    location_kind: location_ref.kind_string(location),
    location: location_ref.key_string(location),
    quantity:,
  )
}

fn to_audit_row(record: AuditRecord) -> location_audits_dao.LocationAuditRow {
  location_audits_dao.LocationAuditRow(
    location_kind: location_ref.kind_string(record.location),
    location: location_ref.key_string(record.location),
    completed_at: timestamp.to_rfc3339(record.completed_at, duration.seconds(0)),
  )
}

// Decrements first: a move's source loses its copy before the destination
// gains it, though neither order can violate a constraint.
fn apply(changes: LedgerChanges, record: AuditRecord) -> Result(Nil, String) {
  sqlite_store.exec_all_atomically(
    list.flatten([
      placed_cards_dao.decrement_statements(list.map(
        changes.decrements,
        to_dao_row,
      )),
      placed_cards_dao.increment_statements(list.map(
        changes.increments,
        to_dao_row,
      )),
      [location_audits_dao.insert_statement(to_audit_row(record))],
    ]),
  )
}

pub fn new() -> ports.CompleteLocationAuditPorts {
  ports.CompleteLocationAuditPorts(
    list_placed:,
    owned_quantities:,
    managed_location_ids:,
    now: timestamp.system_time,
    apply:,
  )
}
