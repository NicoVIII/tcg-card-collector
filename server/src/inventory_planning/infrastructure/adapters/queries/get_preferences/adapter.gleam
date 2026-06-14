import inventory_planning/application/queries/get_preferences/ports
import inventory_planning/infrastructure/stores/preferences_store

pub fn new() -> ports.GetPlanningPreferencesPort {
  ports.GetPlanningPreferencesPort(current: fn() {
    let #(default_sort, default_grouping) = preferences_store.get()
    ports.PlanningPreferencesReadModel(default_sort:, default_grouping:)
  })
}
