import inventory_planning/infrastructure/daos/bulk_spec_dao
import support/test_db

pub fn migration_seeds_the_default_bulk_spec_test() {
  use _db <- test_db.with_temp_db()

  assert bulk_spec_dao.get() == Ok(#("Bulk", "color_identity,type,name"))
}

pub fn update_overwrites_the_singleton_test() {
  use _db <- test_db.with_temp_db()

  let assert Ok(Nil) = bulk_spec_dao.update("Overflow box", "name,set_code")

  assert bulk_spec_dao.get() == Ok(#("Overflow box", "name,set_code"))
}
