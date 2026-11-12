import inventory_planning/domain/managed_location.{type ManagedLocation}
import inventory_planning/domain/placed_ledger_reconciliation.{type PlacedRow}
import inventory_planning/domain/plan_restore

pub type ListPlacedPort =
  fn() -> Result(List(PlacedRow), String)

pub type ListManagedLocationsPort =
  fn() -> Result(List(ManagedLocation), String)

pub type PredictRestorePrunePorts {
  PredictRestorePrunePorts(
    list_placed: ListPlacedPort,
    list_managed_locations: ListManagedLocationsPort,
  )
}

pub type PredictRestorePruneError {
  InvalidPlan(plan_restore.PlanRestoreError)
  /// A ledger row names a managed location that neither exists nor is
  /// being restored — deleting a location removes its rows, so this means
  /// the database was edited by hand.
  UnknownManagedLocation(id: String)
  PersistenceFailed(reason: String)
}
