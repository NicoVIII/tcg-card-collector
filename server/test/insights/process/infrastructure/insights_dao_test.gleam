import insights/infrastructure/daos/insights_dao
import support/test_db

pub fn mark_and_list_round_trip_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = insights_dao.mark("lea")
  let assert Ok(Nil) = insights_dao.mark("2xm")

  assert insights_dao.list() == ["2xm", "lea"]
}

pub fn marking_the_same_set_code_twice_is_idempotent_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = insights_dao.mark("lea")
  let assert Ok(Nil) = insights_dao.mark("lea")

  assert insights_dao.list() == ["lea"]
}

pub fn unmark_removes_the_set_code_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = insights_dao.mark("lea")
  let assert Ok(Nil) = insights_dao.unmark("lea")

  assert insights_dao.list() == []
}
