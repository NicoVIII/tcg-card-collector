import collection/application/commands/import_collection/handler
import collection/application/commands/import_collection/ports
import collection/domain/import_mode
import collection/domain/import_status
import gleam/list
import gleam/option.{type Option, None, Some}
import shared/domain/card_key
import shared/domain/non_empty_string.{type NonEmptyString}
import support/ref

fn build_ports(
  runs runs: ref.Ref(List(ports.ImportRunWriteModel)),
  last_snapshot last_snapshot: ref.Ref(
    Option(#(String, List(ports.SnapshotRowWriteModel))),
  ),
  replace_rows_result replace_rows_result: Result(Nil, String),
  latest_snapshot_rows_result latest_snapshot_rows_result: Result(
    List(ports.LatestSnapshotRow),
    String,
  ),
) -> ports.ImportCollectionPorts {
  ports.ImportCollectionPorts(
    save_run: fn(run) {
      ref.set(runs, [run, ..ref.get(runs)])
      Ok(Nil)
    },
    replace_rows: fn(import_run_id, rows) {
      case replace_rows_result {
        Ok(Nil) -> {
          ref.set(last_snapshot, Some(#(import_run_id, rows)))
          Ok(Nil)
        }
        Error(reason) -> Error(reason)
      }
    },
    latest_snapshot_rows: fn() { latest_snapshot_rows_result },
  )
}

fn last_run_status(
  runs: ref.Ref(List(ports.ImportRunWriteModel)),
) -> import_status.ImportStatus {
  let assert [latest, ..] = ref.get(runs)
  latest.status
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

pub fn valid_rows_succeed_and_persist_snapshot_test() {
  let runs = ref.new([])
  let last_snapshot = ref.new(None)
  let import_ports =
    build_ports(
      runs:,
      last_snapshot:,
      replace_rows_result: Ok(Nil),
      latest_snapshot_rows_result: Ok([]),
    )

  let result =
    handler.execute(
      handler.ImportCollectionCommand(
        import_run_id: nes("run-1"),
        source_name: nes("test.csv"),
        row_count: 2,
        rows: [
          ports.ImportCollectionRow(
            set_code: "lea",
            collector_number: "1",
            quantity: 4,
          ),
          ports.ImportCollectionRow(
            set_code: "lea",
            collector_number: "2",
            quantity: 1,
          ),
        ],
        mode: import_mode.Full,
      ),
      import_ports,
    )

  assert result == Ok(Nil)
  assert last_run_status(runs) == import_status.Succeeded

  let assert Some(#("run-1", saved_rows)) = ref.get(last_snapshot)
  assert snapshot_row_quantity(saved_rows, "lea", "1") == Some(4)
  assert snapshot_row_quantity(saved_rows, "lea", "2") == Some(1)
}

pub fn non_positive_quantity_drops_row_and_mismatches_test() {
  let runs = ref.new([])
  let last_snapshot = ref.new(None)
  let import_ports =
    build_ports(
      runs:,
      last_snapshot:,
      replace_rows_result: Ok(Nil),
      latest_snapshot_rows_result: Ok([]),
    )

  let result =
    handler.execute(
      handler.ImportCollectionCommand(
        import_run_id: nes("run-2"),
        source_name: nes("test.csv"),
        row_count: 1,
        rows: [
          ports.ImportCollectionRow(
            set_code: "lea",
            collector_number: "1",
            quantity: 0,
          ),
        ],
        mode: import_mode.Full,
      ),
      import_ports,
    )

  assert result == Error(ports.RowCountMismatch)
  assert last_run_status(runs) == import_status.Failed
  assert ref.get(last_snapshot) == None
}

pub fn blank_set_code_drops_row_and_mismatches_test() {
  let runs = ref.new([])
  let last_snapshot = ref.new(None)
  let import_ports =
    build_ports(
      runs:,
      last_snapshot:,
      replace_rows_result: Ok(Nil),
      latest_snapshot_rows_result: Ok([]),
    )

  let result =
    handler.execute(
      handler.ImportCollectionCommand(
        import_run_id: nes("run-3"),
        source_name: nes("test.csv"),
        row_count: 1,
        rows: [
          ports.ImportCollectionRow(
            set_code: "",
            collector_number: "1",
            quantity: 2,
          ),
        ],
        mode: import_mode.Full,
      ),
      import_ports,
    )

  assert result == Error(ports.RowCountMismatch)
  assert last_run_status(runs) == import_status.Failed
}

pub fn snapshot_persistence_failure_reports_error_and_marks_failed_test() {
  let runs = ref.new([])
  let last_snapshot = ref.new(None)
  let import_ports =
    build_ports(
      runs:,
      last_snapshot:,
      replace_rows_result: Error("disk full"),
      latest_snapshot_rows_result: Ok([]),
    )

  let result =
    handler.execute(
      handler.ImportCollectionCommand(
        import_run_id: nes("run-4"),
        source_name: nes("test.csv"),
        row_count: 1,
        rows: [
          ports.ImportCollectionRow(
            set_code: "lea",
            collector_number: "1",
            quantity: 1,
          ),
        ],
        mode: import_mode.Full,
      ),
      import_ports,
    )

  assert result == Error(ports.PersistenceFailed("disk full"))
  assert last_run_status(runs) == import_status.Failed
}

pub fn delta_mode_adds_new_card_to_previous_snapshot_test() {
  let runs = ref.new([])
  let last_snapshot = ref.new(None)
  let previous = [
    ports.LatestSnapshotRow(key: assert_card_key("lea", "1"), quantity: 4),
  ]
  let import_ports =
    build_ports(
      runs:,
      last_snapshot:,
      replace_rows_result: Ok(Nil),
      latest_snapshot_rows_result: Ok(previous),
    )

  let result =
    handler.execute(
      handler.ImportCollectionCommand(
        import_run_id: nes("run-5"),
        source_name: nes("delta.csv"),
        row_count: 1,
        rows: [
          ports.ImportCollectionRow(
            set_code: "lea",
            collector_number: "2",
            quantity: 1,
          ),
        ],
        mode: import_mode.Delta,
      ),
      import_ports,
    )

  assert result == Ok(Nil)
  assert last_run_status(runs) == import_status.Succeeded

  let assert Some(#("run-5", saved_rows)) = ref.get(last_snapshot)
  assert snapshot_row_quantity(saved_rows, "lea", "1") == Some(4)
  assert snapshot_row_quantity(saved_rows, "lea", "2") == Some(1)
}

pub fn delta_mode_sums_quantity_for_existing_card_test() {
  let runs = ref.new([])
  let last_snapshot = ref.new(None)
  let previous = [
    ports.LatestSnapshotRow(key: assert_card_key("lea", "1"), quantity: 4),
  ]
  let import_ports =
    build_ports(
      runs:,
      last_snapshot:,
      replace_rows_result: Ok(Nil),
      latest_snapshot_rows_result: Ok(previous),
    )

  let result =
    handler.execute(
      handler.ImportCollectionCommand(
        import_run_id: nes("run-6"),
        source_name: nes("delta.csv"),
        row_count: 1,
        rows: [
          ports.ImportCollectionRow(
            set_code: "lea",
            collector_number: "1",
            quantity: 3,
          ),
        ],
        mode: import_mode.Delta,
      ),
      import_ports,
    )

  assert result == Ok(Nil)

  let assert Some(#("run-6", saved_rows)) = ref.get(last_snapshot)
  assert snapshot_row_quantity(saved_rows, "lea", "1") == Some(7)
}

pub fn delta_mode_previous_rows_read_failure_fails_the_run_test() {
  let runs = ref.new([])
  let last_snapshot = ref.new(None)
  let import_ports =
    build_ports(
      runs:,
      last_snapshot:,
      replace_rows_result: Ok(Nil),
      latest_snapshot_rows_result: Error("db unavailable"),
    )

  let result =
    handler.execute(
      handler.ImportCollectionCommand(
        import_run_id: nes("run-7"),
        source_name: nes("delta.csv"),
        row_count: 1,
        rows: [
          ports.ImportCollectionRow(
            set_code: "lea",
            collector_number: "1",
            quantity: 1,
          ),
        ],
        mode: import_mode.Delta,
      ),
      import_ports,
    )

  assert result == Error(ports.PersistenceFailed("db unavailable"))
  assert last_run_status(runs) == import_status.Failed
  assert ref.get(last_snapshot) == None
}

pub fn full_mode_sums_duplicate_keys_within_the_same_import_test() {
  let runs = ref.new([])
  let last_snapshot = ref.new(None)
  let import_ports =
    build_ports(
      runs:,
      last_snapshot:,
      replace_rows_result: Ok(Nil),
      latest_snapshot_rows_result: Ok([]),
    )

  let result =
    handler.execute(
      handler.ImportCollectionCommand(
        import_run_id: nes("run-8"),
        source_name: nes("test.csv"),
        row_count: 2,
        rows: [
          ports.ImportCollectionRow(
            set_code: "lea",
            collector_number: "1",
            quantity: 2,
          ),
          ports.ImportCollectionRow(
            set_code: "lea",
            collector_number: "1",
            quantity: 3,
          ),
        ],
        mode: import_mode.Full,
      ),
      import_ports,
    )

  assert result == Ok(Nil)

  let assert Some(#("run-8", saved_rows)) = ref.get(last_snapshot)
  assert list.length(saved_rows) == 1
  assert snapshot_row_quantity(saved_rows, "lea", "1") == Some(5)
}
