import inventory_planning/application/commands/update_bulk_spec/ports
import inventory_planning/infrastructure/daos/bulk_spec_dao

pub fn new() -> ports.UpdateBulkSpecPort {
  ports.UpdateBulkSpecPort(update: fn(spec) {
    let ports.BulkSpecWriteModel(
      location_name: location_name,
      sort_keys: sort_keys,
    ) = spec
    bulk_spec_dao.update(location_name, sort_keys)
  })
}
