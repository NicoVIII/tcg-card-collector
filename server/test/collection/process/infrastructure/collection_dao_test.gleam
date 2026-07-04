import collection/domain/import_mode
import collection/domain/import_status
import collection/infrastructure/daos/collection_dao
import gleam/option.{None, Some}
import support/test_db

pub fn save_and_latest_round_trip_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) =
    collection_dao.save(
      "run-1",
      "test.csv",
      import_status.Succeeded,
      2,
      import_mode.Full,
    )

  assert collection_dao.latest()
    == Some(#("run-1", "test.csv", import_status.Succeeded, 2))
}

pub fn latest_returns_none_when_no_runs_test() {
  use _db <- test_db.with_temp_db()

  assert collection_dao.latest() == None
}

pub fn replace_rows_and_snapshot_rows_round_trip_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) =
    collection_dao.save(
      "run-1",
      "test.csv",
      import_status.Succeeded,
      2,
      import_mode.Full,
    )
  let assert Ok(Nil) =
    collection_dao.replace_rows("run-1", [
      #("lea", "1", 4),
      #("lea", "2", 1),
    ])

  assert collection_dao.snapshot_rows() == [#("lea", "1", 4), #("lea", "2", 1)]
  assert collection_dao.latest_snapshot_rows()
    == Ok([#("lea", "1", 4), #("lea", "2", 1)])
}

pub fn snapshot_rows_ignores_non_succeeded_runs_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) =
    collection_dao.save(
      "run-1",
      "test.csv",
      import_status.Failed,
      1,
      import_mode.Full,
    )
  let assert Ok(Nil) = collection_dao.replace_rows("run-1", [#("lea", "1", 4)])

  assert collection_dao.snapshot_rows() == []
}

pub fn replace_rows_discards_previous_rows_for_the_same_run_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) =
    collection_dao.save(
      "run-1",
      "test.csv",
      import_status.Succeeded,
      1,
      import_mode.Full,
    )
  let assert Ok(Nil) = collection_dao.replace_rows("run-1", [#("lea", "1", 4)])
  let assert Ok(Nil) = collection_dao.replace_rows("run-1", [#("lea", "2", 9)])

  assert collection_dao.snapshot_rows() == [#("lea", "2", 9)]
}
