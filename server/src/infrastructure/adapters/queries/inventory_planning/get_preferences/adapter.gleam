import application/queries/inventory_planning/get_preferences/ports
import infrastructure/stores/inventory_planning/preferences_store

pub fn new() -> ports.GetPlanningPreferencesPort {
  ports.GetPlanningPreferencesPort(current: fn() {
    let #(default_sort, default_grouping) = preferences_store.get()
    ports.PlanningPreferencesReadModel(default_sort:, default_grouping:)
  })
}
