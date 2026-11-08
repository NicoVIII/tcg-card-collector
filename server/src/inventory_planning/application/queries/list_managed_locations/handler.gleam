import inventory_planning/application/queries/list_managed_locations/ports
import inventory_planning/domain/managed_location.{type ManagedLocation}

pub type ListManagedLocationsQuery {
  ListManagedLocationsQuery
}

/// Every managed location with its full membership — including copies the
/// collection no longer owns; the shortfall is the projection's to derive.
pub fn execute(
  _query: ListManagedLocationsQuery,
  port: ports.ListManagedLocationsPort,
) -> Result(List(ManagedLocation), String) {
  port()
}
