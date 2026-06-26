import collection/infrastructure/daos/collection_dao

pub fn snapshot_rows() -> List(#(String, String, Int)) {
  collection_dao.snapshot_rows()
}
