import insights/infrastructure/daos/insights_dao
import support/test_db

pub fn mark_and_list_round_trip_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = insights_dao.mark("lea")
  let assert Ok(Nil) = insights_dao.mark("2xm")

  assert insights_dao.list() == Ok(["2xm", "lea"])
}

pub fn marking_the_same_set_code_twice_is_idempotent_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = insights_dao.mark("lea")
  let assert Ok(Nil) = insights_dao.mark("lea")

  assert insights_dao.list() == Ok(["lea"])
}

pub fn unmark_removes_the_set_code_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = insights_dao.mark("lea")
  let assert Ok(Nil) = insights_dao.unmark("lea")

  assert insights_dao.list() == Ok([])
}

pub fn replace_swaps_every_target_set_at_once_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = insights_dao.mark("lea")
  let assert Ok(Nil) = insights_dao.replace(["2xm", "neo"])

  assert insights_dao.list() == Ok(["2xm", "neo"])
}

pub fn replace_with_an_empty_list_clears_every_target_set_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = insights_dao.mark("lea")
  let assert Ok(Nil) = insights_dao.replace([])

  assert insights_dao.list() == Ok([])
}
