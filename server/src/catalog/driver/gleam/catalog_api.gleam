import catalog/infrastructure/daos/catalog_dao

pub fn name_lookup() -> List(#(String, String, String)) {
  catalog_dao.name_lookup()
}
