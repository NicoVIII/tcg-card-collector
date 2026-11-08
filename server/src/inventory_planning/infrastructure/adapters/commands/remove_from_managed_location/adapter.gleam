import gleam/list
import inventory_planning/application/commands/remove_from_managed_location/ports
import inventory_planning/infrastructure/daos/managed_locations_dao

pub fn new() -> ports.RemoveFromManagedLocationPorts {
  ports.RemoveFromManagedLocationPorts(
    list_locations: managed_locations_dao.load_all,
    decrement_members: fn(id, deltas) {
      managed_locations_dao.decrement_members(
        list.map(deltas, managed_locations_dao.member_row(id, _)),
      )
    },
  )
}
