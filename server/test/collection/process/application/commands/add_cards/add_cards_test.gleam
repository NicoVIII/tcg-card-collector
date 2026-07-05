import collection/application/commands/add_cards/handler
import collection/application/commands/add_cards/ports
import collection/domain/import_status
import gleam/list
import gleam/option.{type Option, None, Some}
import shared/domain/card_key
import shared/domain/non_empty_string.{type NonEmptyString}
import support/ref

fn build_ports(
  runs runs: ref.Ref(List(ports.AddRunWriteModel)),
  last_snapshot last_snapshot: ref.Ref(
    Option(#(String, List(ports.SnapshotRowWriteModel))),
  ),
  replace_rows_result replace_rows_result: Result(Nil, String),
  latest_snapshot_rows_result latest_snapshot_rows_result: Result(
    List(ports.LatestSnapshotRow),
    String,
  ),
) -> ports.AddCardsPorts {
  ports.AddCardsPorts(
    save_run: fn(run) {
      ref.set(runs, [run, ..ref.get(runs)])
      Ok(Nil)
    },
    replace_rows: fn(add_run_id, rows) {
      case replace_rows_result {
        Ok(Nil) -> {
          ref.set(last_snapshot, Some(#(add_run_id, rows)))
          Ok(Nil)
        }
        Error(reason) -> Error(reason)
      }
    },
    latest_snapshot_rows: fn() { latest_snapshot_rows_result },
  )
}

fn last_run(
  runs: ref.Ref(List(ports.AddRunWriteModel)),
) -> ports.AddRunWriteModel {
  let assert [latest, ..] = ref.get(runs)
  latest
}

fn assert_card_key(
  set_code: String,
  collector_number: String,
) -> card_key.CardKey {
  let assert Ok(key) =
    card_key.new(set_code: set_code, collector_number: collector_number)
  key
}

fn nes(value: String) -> NonEmptyString {
  let assert Ok(value_nes) = non_empty_string.new(value)
  value_nes
}

fn snapshot_row_quantity(
  rows: List(ports.SnapshotRowWriteModel),
  set_code: String,
  collector_number: String,
) -> Option(Int) {
  let key = assert_card_key(set_code, collector_number)
  case list.find(rows, fn(row) { row.key == key }) {
    Ok(row) -> Some(row.quantity)
    Error(Nil) -> None
  }
}

pub fn adds_new_card_on_top_of_previous_snapshot_test() {
  let runs = ref.new([])
  let last_snapshot = ref.new(None)
  let previous = [
    ports.LatestSnapshotRow(key: assert_card_key("lea", "1"), quantity: 4),
  ]
  let add_ports =
    build_ports(
      runs:,
      last_snapshot:,
      replace_rows_result: Ok(Nil),
      latest_snapshot_rows_result: Ok(previous),
    )

  let result =
    handler.execute(
      handler.AddCardsCommand(add_run_id: nes("add-1"), rows: [
        ports.AddCardsRow(set_code: "lea", collector_number: "2", quantity: 1),
      ]),
      add_ports,
    )

  assert result == Ok(Nil)
  assert last_run(runs).status == import_status.Succeeded
  assert last_run(runs).source_name == "manual-add"

  let assert Some(#("add-1", saved_rows)) = ref.get(last_snapshot)
  assert snapshot_row_quantity(saved_rows, "lea", "1") == Some(4)
  assert snapshot_row_quantity(saved_rows, "lea", "2") == Some(1)
}

pub fn sums_quantity_for_card_already_in_collection_test() {
  let runs = ref.new([])
  let last_snapshot = ref.new(None)
  let previous = [
    ports.LatestSnapshotRow(key: assert_card_key("lea", "1"), quantity: 4),
  ]
  let add_ports =
    build_ports(
      runs:,
      last_snapshot:,
      replace_rows_result: Ok(Nil),
      latest_snapshot_rows_result: Ok(previous),
    )

  let result =
    handler.execute(
      handler.AddCardsCommand(add_run_id: nes("add-2"), rows: [
        ports.AddCardsRow(set_code: "lea", collector_number: "1", quantity: 3),
      ]),
      add_ports,
    )

  assert result == Ok(Nil)

  let assert Some(#("add-2", saved_rows)) = ref.get(last_snapshot)
  assert snapshot_row_quantity(saved_rows, "lea", "1") == Some(7)
}

pub fn duplicate_keys_within_one_batch_are_summed_test() {
  let runs = ref.new([])
  let last_snapshot = ref.new(None)
  let add_ports =
    build_ports(
      runs:,
      last_snapshot:,
      replace_rows_result: Ok(Nil),
      latest_snapshot_rows_result: Ok([]),
    )

  let result =
    handler.execute(
      handler.AddCardsCommand(add_run_id: nes("add-3"), rows: [
        ports.AddCardsRow(set_code: "lea", collector_number: "1", quantity: 2),
        ports.AddCardsRow(set_code: "lea", collector_number: "1", quantity: 3),
      ]),
      add_ports,
    )

  assert result == Ok(Nil)
  // The run records how many rows were sent, even when they collapse to one.
  assert last_run(runs).row_count == 2

  let assert Some(#("add-3", saved_rows)) = ref.get(last_snapshot)
  assert list.length(saved_rows) == 1
  assert snapshot_row_quantity(saved_rows, "lea", "1") == Some(5)
}

pub fn one_invalid_row_rejects_the_whole_batch_test() {
  let runs = ref.new([])
  let last_snapshot = ref.new(None)
  let add_ports =
    build_ports(
      runs:,
      last_snapshot:,
      replace_rows_result: Ok(Nil),
      latest_snapshot_rows_result: Ok([]),
    )

  let result =
    handler.execute(
      handler.AddCardsCommand(add_run_id: nes("add-4"), rows: [
        ports.AddCardsRow(set_code: "lea", collector_number: "1", quantity: 1),
        ports.AddCardsRow(set_code: "", collector_number: "2", quantity: 1),
      ]),
      add_ports,
    )

  assert result == Error(ports.InvalidRows)
  assert last_run(runs).status == import_status.Failed
  assert ref.get(last_snapshot) == None
}

pub fn empty_batch_is_rejected_test() {
  let runs = ref.new([])
  let last_snapshot = ref.new(None)
  let add_ports =
    build_ports(
      runs:,
      last_snapshot:,
      replace_rows_result: Ok(Nil),
      latest_snapshot_rows_result: Ok([]),
    )

  let result =
    handler.execute(
      handler.AddCardsCommand(add_run_id: nes("add-5"), rows: []),
      add_ports,
    )

  assert result == Error(ports.InvalidRows)
  assert ref.get(last_snapshot) == None
}

pub fn previous_rows_read_failure_fails_the_run_test() {
  let runs = ref.new([])
  let last_snapshot = ref.new(None)
  let add_ports =
    build_ports(
      runs:,
      last_snapshot:,
      replace_rows_result: Ok(Nil),
      latest_snapshot_rows_result: Error("db unavailable"),
    )

  let result =
    handler.execute(
      handler.AddCardsCommand(add_run_id: nes("add-6"), rows: [
        ports.AddCardsRow(set_code: "lea", collector_number: "1", quantity: 1),
      ]),
      add_ports,
    )

  assert result == Error(ports.PersistenceFailed("db unavailable"))
  assert last_run(runs).status == import_status.Failed
  assert ref.get(last_snapshot) == None
}

pub fn snapshot_persistence_failure_reports_error_and_marks_failed_test() {
  let runs = ref.new([])
  let last_snapshot = ref.new(None)
  let add_ports =
    build_ports(
      runs:,
      last_snapshot:,
      replace_rows_result: Error("disk full"),
      latest_snapshot_rows_result: Ok([]),
    )

  let result =
    handler.execute(
      handler.AddCardsCommand(add_run_id: nes("add-7"), rows: [
        ports.AddCardsRow(set_code: "lea", collector_number: "1", quantity: 1),
      ]),
      add_ports,
    )

  assert result == Error(ports.PersistenceFailed("disk full"))
  assert last_run(runs).status == import_status.Failed
}
