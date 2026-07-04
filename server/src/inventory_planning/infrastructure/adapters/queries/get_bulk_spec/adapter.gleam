import inventory_planning/application/queries/get_bulk_spec/ports
import inventory_planning/infrastructure/daos/bulk_spec_dao

pub fn new() -> ports.GetBulkSpecPort {
  ports.GetBulkSpecPort(current: fn() {
    let #(location_name, sort_keys) = bulk_spec_dao.get()
    ports.BulkSpecReadModel(location_name:, sort_keys:)
  })
}
