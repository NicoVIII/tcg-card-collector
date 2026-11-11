import gleam/dict
import gleam/option.{type Option, None, Some}
import gleam/time/timestamp
import inventory_planning/application/commands/complete_location_audit/handler.{
  CompleteLocationAuditCommand, RawAuditedCopy, RawLocation, RawUnexpectedCopy,
}
import inventory_planning/application/commands/complete_location_audit/ports
import inventory_planning/domain/location_audit.{
  type AuditRecord, type LedgerChanges, AuditRecord, ExceedsOwned, LedgerChanges,
}
import inventory_planning/domain/location_ref.{Cascade, Managed}
import inventory_planning/domain/placed_ledger_reconciliation.{PlacedRow}
import shared/domain/copy_key.{type CopyKey}
import support/ref

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

fn raw(collector_number: String, quantity: Int) -> handler.RawAuditedCopy {
  RawAuditedCopy(
    set_code: "LEA",
    collector_number:,
    finish: "nonfoil",
    language: "en",
    quantity:,
  )
}

const now = 1_700_000_000

// lea 1: 2 in the binder, 1 in deck d1, 3 owned. lea 2: owned once, unplaced.
fn build_ports(
  written: ref.Ref(Option(#(LedgerChanges, AuditRecord))),
) -> ports.CompleteLocationAuditPorts {
  ports.CompleteLocationAuditPorts(
    list_placed: fn() {
      Ok([
        PlacedRow(key: key("1"), location: Cascade("Binder"), quantity: 2),
        PlacedRow(key: key("1"), location: Managed("d1"), quantity: 1),
      ])
    },
    owned_quantities: fn() {
      Ok(dict.from_list([#(key("1"), 3), #(key("2"), 1)]))
    },
    managed_location_ids: fn() { Ok(["d1"]) },
    now: fn() { timestamp.from_unix_seconds(now) },
    apply: fn(changes, record) {
      ref.set(written, Some(#(changes, record)))
      Ok(Nil)
    },
  )
}

fn complete(command: handler.CompleteLocationAuditCommand) {
  let written = ref.new(None)
  let result = handler.execute(command, build_ports(written))
  #(result, ref.get(written))
}

fn binder_audit(missing, unexpected) {
  CompleteLocationAuditCommand(
    location: RawLocation(kind: "cascade", key: "Binder"),
    missing:,
    unexpected:,
  )
}

pub fn completing_applies_every_finding_and_stamps_the_history_test() {
  let command =
    binder_audit([raw("1", 1)], [
      RawUnexpectedCopy(copy: raw("2", 1), source: None),
    ])

  assert complete(command)
    == #(
      Ok(Nil),
      Some(#(
        LedgerChanges(
          decrements: [
            PlacedRow(key: key("1"), location: Cascade("Binder"), quantity: 1),
          ],
          increments: [
            PlacedRow(key: key("2"), location: Cascade("Binder"), quantity: 1),
          ],
        ),
        AuditRecord(
          location: Cascade("Binder"),
          completed_at: timestamp.from_unix_seconds(now),
        ),
      )),
    )
}

pub fn a_misfiled_copy_moves_from_its_named_source_test() {
  let command =
    binder_audit([], [
      RawUnexpectedCopy(
        copy: raw("1", 1),
        source: Some(RawLocation(kind: "managed", key: "d1")),
      ),
    ])

  let assert #(Ok(Nil), Some(#(changes, _))) = complete(command)
  assert changes
    == LedgerChanges(
      decrements: [
        PlacedRow(key: key("1"), location: Managed("d1"), quantity: 1),
      ],
      increments: [
        PlacedRow(key: key("1"), location: Cascade("Binder"), quantity: 1),
      ],
    )
}

pub fn an_audit_with_nothing_but_confirmations_still_stamps_test() {
  let assert #(Ok(Nil), Some(#(changes, _))) = complete(binder_audit([], []))
  assert changes == LedgerChanges(decrements: [], increments: [])
}

pub fn a_contradicted_finding_writes_nothing_test() {
  let command =
    binder_audit([], [RawUnexpectedCopy(copy: raw("1", 1), source: None)])

  assert complete(command)
    == #(
      Error(
        ports.Rejected(ExceedsOwned(key: key("1"), requested: 1, available: 0)),
      ),
      None,
    )
}

pub fn a_deleted_deck_is_rejected_test() {
  let command =
    CompleteLocationAuditCommand(
      location: RawLocation(kind: "managed", key: "gone"),
      missing: [],
      unexpected: [],
    )

  assert complete(command) == #(Error(ports.UnknownLocation), None)
}

pub fn malformed_findings_are_rejected_test() {
  assert complete(binder_audit([raw("1", 0)], []))
    == #(Error(ports.InvalidAudit), None)
  assert complete(
      CompleteLocationAuditCommand(
        location: RawLocation(kind: "cascade", key: "  "),
        missing: [],
        unexpected: [],
      ),
    )
    == #(Error(ports.InvalidAudit), None)
}
