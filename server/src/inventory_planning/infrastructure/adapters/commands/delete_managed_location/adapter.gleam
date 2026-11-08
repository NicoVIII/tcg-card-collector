import inventory_planning/application/commands/delete_managed_location/ports
import inventory_planning/infrastructure/daos/managed_locations_dao

pub fn new() -> ports.DeleteManagedLocationPorts {
  ports.DeleteManagedLocationPorts(
    list_locations: managed_locations_dao.load_all,
    delete: managed_locations_dao.delete,
  )
}
