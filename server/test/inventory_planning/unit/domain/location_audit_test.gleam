import gleam/dict
import gleam/option.{None, Some}
import gleam/time/timestamp
import inventory_planning/domain/location_audit.{
  AuditRecord, ExceedsOwned, LedgerChanges, Missing, MissingAndUnexpected,
  NonPositiveQuantity, NotRecordedAtSource, NotRecordedHere,
  SourceIsAuditedLocation, Unexpected,
}
import inventory_planning/domain/location_ref.{Cascade, Managed}
import inventory_planning/domain/placed_ledger_reconciliation.{PlacedRow}
import shared/domain/copy_key.{type CopyKey}

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

const binder = Cascade("Binder")

const box = Cascade("Box")

// lea 1: 2 in the binder, 1 in the box, 3 owned.
// lea 2: 1 in the box, 2 owned.
fn ledger() {
  [
    PlacedRow(key: key("1"), location: binder, quantity: 2),
    PlacedRow(key: key("1"), location: box, quantity: 1),
    PlacedRow(key: key("2"), location: box, quantity: 1),
  ]
}

fn owned() {
  dict.from_list([#(key("1"), 3), #(key("2"), 2)])
}

fn changes(findings) {
  let assert Ok(audit) = location_audit.new(binder, findings)
  location_audit.ledger_changes(audit, ledger(), owned())
}

pub fn a_fully_confirmed_audit_changes_nothing_test() {
  assert changes([]) == Ok(LedgerChanges(decrements: [], increments: []))
}

pub fn a_missing_copy_comes_off_the_audited_location_test() {
  assert changes([Missing(key("1"), 2)])
    == Ok(
      LedgerChanges(
        decrements: [PlacedRow(key: key("1"), location: binder, quantity: 2)],
        increments: [],
      ),
    )
}

pub fn more_missing_than_recorded_here_is_rejected_test() {
  assert changes([Missing(key("1"), 3)])
    == Error(NotRecordedHere(key: key("1"), requested: 3, recorded: 2))
}

pub fn an_unexpected_copy_within_owned_is_marked_here_test() {
  assert changes([Unexpected(key("2"), 1, None)])
    == Ok(
      LedgerChanges(decrements: [], increments: [
        PlacedRow(key: key("2"), location: binder, quantity: 1),
      ]),
    )
}

// lea 1 is fully placed already: one found here must have come from somewhere.
pub fn an_unsourced_copy_beyond_owned_is_rejected_test() {
  assert changes([Unexpected(key("1"), 1, None)])
    == Error(ExceedsOwned(key: key("1"), requested: 1, available: 0))
}

pub fn a_sourced_copy_moves_from_its_source_test() {
  assert changes([Unexpected(key("1"), 1, Some(box))])
    == Ok(
      LedgerChanges(
        decrements: [PlacedRow(key: key("1"), location: box, quantity: 1)],
        increments: [PlacedRow(key: key("1"), location: binder, quantity: 1)],
      ),
    )
}

pub fn moving_more_than_the_source_records_is_rejected_test() {
  assert changes([Unexpected(key("2"), 2, Some(box))])
    == Error(NotRecordedAtSource(
      key: key("2"),
      source: box,
      requested: 2,
      recorded: 1,
    ))
}

// Two entries for one copy are one request, checked as a whole.
pub fn findings_for_the_same_copy_are_merged_before_checking_test() {
  assert changes([Missing(key("1"), 1), Missing(key("1"), 2)])
    == Error(NotRecordedHere(key: key("1"), requested: 3, recorded: 2))
}

pub fn invalid_finding_sets_are_rejected_test() {
  assert location_audit.new(binder, [Missing(key("1"), 0)])
    == Error(NonPositiveQuantity)
  assert location_audit.new(binder, [Unexpected(key("1"), 1, Some(binder))])
    == Error(SourceIsAuditedLocation)
  assert location_audit.new(binder, [
      Missing(key("1"), 1),
      Unexpected(key("1"), 1, None),
    ])
    == Error(MissingAndUnexpected(key("1")))
}

pub fn latest_per_location_keeps_each_locations_newest_test() {
  let t1 = timestamp.from_unix_seconds(100)
  let t2 = timestamp.from_unix_seconds(200)
  let deck = Managed("d1")

  assert location_audit.latest_per_location([
      AuditRecord(location: binder, completed_at: t2),
      AuditRecord(location: deck, completed_at: t1),
      AuditRecord(location: binder, completed_at: t1),
    ])
    == [
      AuditRecord(location: binder, completed_at: t2),
      AuditRecord(location: deck, completed_at: t1),
    ]
}
