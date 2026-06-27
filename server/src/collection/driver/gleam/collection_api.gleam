// nolint: depends_only_on -- Shortcut for now, fix later
import collection/infrastructure/daos/collection_dao

pub fn snapshot_rows() -> List(#(String, String, Int)) {
  collection_dao.snapshot_rows()
}
