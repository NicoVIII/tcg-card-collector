import inventory_planning/application/commands/create_managed_location/ports
import inventory_planning/domain/managed_location
import inventory_planning/infrastructure/daos/managed_locations_dao

pub fn new() -> ports.CreateManagedLocationPorts {
  ports.CreateManagedLocationPorts(
    list_locations: managed_locations_dao.load_all,
    insert: fn(model) {
      managed_locations_dao.insert(managed_locations_dao.ManagedLocationRow(
        id: model.id,
        name: model.name,
        kind: managed_location.kind_to_string(model.kind),
      ))
    },
  )
}
