import inventory_planning/application/commands/rename_managed_location/ports
import inventory_planning/infrastructure/daos/managed_locations_dao

pub fn new() -> ports.RenameManagedLocationPorts {
  ports.RenameManagedLocationPorts(
    list_locations: managed_locations_dao.load_all,
    rename: managed_locations_dao.rename,
  )
}
