import collection/application/commands/import_collection/handler
import collection/application/commands/import_collection/ports
import collection/domain/import_status
import gleam/list
import gleam/option.{type Option, None, Some}
import support/ref

fn build_ports(
  runs runs: ref.Ref(List(ports.ImportRunWriteModel)),
  last_snapshot last_snapshot: ref.Ref(
    Option(#(String, List(ports.SnapshotRowWriteModel))),
  ),
  replace_rows_result replace_rows_result: Result(Nil, String),
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
  )
}

fn last_run_status(
  runs: ref.Ref(List(ports.ImportRunWriteModel)),
) -> import_status.ImportStatus {
  let assert [latest, ..] = ref.get(runs)
  latest.status
}

pub fn valid_rows_succeed_and_persist_snapshot_test() {
  let runs = ref.new([])
  let last_snapshot = ref.new(None)
  let import_ports =
    build_ports(runs:, last_snapshot:, replace_rows_result: Ok(Nil))

  let result =
    handler.execute(
      handler.ImportCollectionCommand(
        import_run_id: "run-1",
        source_name: "test.csv",
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
      ),
      import_ports,
    )

  assert result == Ok(Nil)
  assert last_run_status(runs) == import_status.Succeeded

  let assert Some(#("run-1", saved_rows)) = ref.get(last_snapshot)
  assert list.map(saved_rows, fn(row) { row.quantity }) == [4, 1]
}

pub fn non_positive_quantity_drops_row_and_mismatches_test() {
  let runs = ref.new([])
  let last_snapshot = ref.new(None)
  let import_ports =
    build_ports(runs:, last_snapshot:, replace_rows_result: Ok(Nil))

  let result =
    handler.execute(
      handler.ImportCollectionCommand(
        import_run_id: "run-2",
        source_name: "test.csv",
        row_count: 1,
        rows: [
          ports.ImportCollectionRow(
            set_code: "lea",
            collector_number: "1",
            quantity: 0,
          ),
        ],
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
    build_ports(runs:, last_snapshot:, replace_rows_result: Ok(Nil))

  let result =
    handler.execute(
      handler.ImportCollectionCommand(
        import_run_id: "run-3",
        source_name: "test.csv",
        row_count: 1,
        rows: [
          ports.ImportCollectionRow(
            set_code: "",
            collector_number: "1",
            quantity: 2,
          ),
        ],
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
    build_ports(runs:, last_snapshot:, replace_rows_result: Error("disk full"))

  let result =
    handler.execute(
      handler.ImportCollectionCommand(
        import_run_id: "run-4",
        source_name: "test.csv",
        row_count: 1,
        rows: [
          ports.ImportCollectionRow(
            set_code: "lea",
            collector_number: "1",
            quantity: 1,
          ),
        ],
      ),
      import_ports,
    )

  assert result == Error(ports.PersistenceFailed("disk full"))
  assert last_run_status(runs) == import_status.Failed
}
