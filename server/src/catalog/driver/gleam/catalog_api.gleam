// nolint: depends_only_on -- Shortcut for now, fix later
import catalog/infrastructure/daos/catalog_dao

pub fn name_lookup() -> List(#(String, String, String)) {
  catalog_dao.name_lookup()
}
