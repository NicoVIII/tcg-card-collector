import inventory_planning/application/queries/list_managed_locations/ports
import inventory_planning/infrastructure/daos/managed_locations_dao

pub fn new() -> ports.ListManagedLocationsPort {
  managed_locations_dao.load_all
}
