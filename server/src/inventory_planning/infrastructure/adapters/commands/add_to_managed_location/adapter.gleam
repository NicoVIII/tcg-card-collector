import collection/driver/gleam/collection_api
import gleam/dict
import gleam/list
import gleam/result
import inventory_planning/application/commands/add_to_managed_location/ports
import inventory_planning/infrastructure/daos/managed_locations_dao

pub fn new() -> ports.AddToManagedLocationPorts {
  ports.AddToManagedLocationPorts(
    list_locations: managed_locations_dao.load_all,
    owned_quantities: fn() {
      use copies <- result.map(collection_api.list_copies())
      dict.from_list(list.map(copies, fn(copy) { #(copy.key, copy.quantity) }))
    },
    increment_members: fn(id, deltas) {
      managed_locations_dao.increment_members(
        list.map(deltas, managed_locations_dao.member_row(id, _)),
      )
    },
  )
}
