import gleam/time/timestamp
import inventory_planning/domain/location_audit.{AuditRecord, LedgerChanges}
import inventory_planning/domain/location_ref.{Cascade}
import inventory_planning/domain/placed_ledger_reconciliation.{PlacedRow}
import inventory_planning/infrastructure/adapters/commands/complete_location_audit/adapter as complete_adapter
import inventory_planning/infrastructure/adapters/queries/list_location_audits/adapter as list_adapter
import inventory_planning/infrastructure/daos/placed_cards_dao.{
  type PlacedCardRow, PlacedCardRow,
}
import shared/domain/copy_key.{type CopyKey}
import support/test_db

fn key(collector_number: String) -> CopyKey {
  let assert Ok(key) =
    copy_key.new(
      set_code: "lea",
      collector_number:,
      finish: "nonfoil",
      language: "en",
    )
  key
}

fn cascade_row(
  collector_number: String,
  location: String,
  quantity: Int,
) -> PlacedCardRow {
  PlacedCardRow(
    "lea",
    collector_number,
    "nonfoil",
    "en",
    "cascade",
    location,
    quantity,
  )
}

pub fn apply_writes_the_ledger_changes_and_the_record_test() {
  use _db <- test_db.with_temp_db()
  let assert Ok(Nil) =
    placed_cards_dao.increment([
      cascade_row("1", "Binder", 2),
      cascade_row("2", "Box", 1),
    ])
  let ports = complete_adapter.new()
  let completed_at = timestamp.from_unix_seconds(1_700_000_000)

  let assert Ok(Nil) =
    ports.apply(
      LedgerChanges(
        decrements: [
          PlacedRow(key: key("1"), location: Cascade("Binder"), quantity: 2),
          PlacedRow(key: key("2"), location: Cascade("Box"), quantity: 1),
        ],
        increments: [
          PlacedRow(key: key("2"), location: Cascade("Binder"), quantity: 1),
        ],
      ),
      AuditRecord(location: Cascade("Binder"), completed_at:),
    )

  assert placed_cards_dao.list() == Ok([cascade_row("2", "Binder", 1)])
  assert list_adapter.new()()
    == Ok([AuditRecord(location: Cascade("Binder"), completed_at:)])
}

// The same location audited twice in one second collides on the history's
// primary key; the ledger writes before it must roll back with it.
pub fn a_failed_record_rolls_back_the_ledger_changes_test() {
  use _db <- test_db.with_temp_db()
  let assert Ok(Nil) =
    placed_cards_dao.increment([cascade_row("1", "Binder", 2)])
  let ports = complete_adapter.new()
  let record =
    AuditRecord(
      location: Cascade("Binder"),
      completed_at: timestamp.from_unix_seconds(1_700_000_000),
    )
  let unmark_one =
    LedgerChanges(
      decrements: [
        PlacedRow(key: key("1"), location: Cascade("Binder"), quantity: 1),
      ],
      increments: [],
    )
  let assert Ok(Nil) = ports.apply(unmark_one, record)

  let assert Error(_) = ports.apply(unmark_one, record)

  assert placed_cards_dao.list() == Ok([cascade_row("1", "Binder", 1)])
}

pub fn list_placed_reads_the_ledger_as_domain_rows_test() {
  use _db <- test_db.with_temp_db()
  let assert Ok(Nil) =
    placed_cards_dao.increment([cascade_row("1", "Binder", 2)])

  assert complete_adapter.new().list_placed()
    == Ok([PlacedRow(key: key("1"), location: Cascade("Binder"), quantity: 2)])
  assert complete_adapter.new().managed_location_ids() == Ok([])
}
