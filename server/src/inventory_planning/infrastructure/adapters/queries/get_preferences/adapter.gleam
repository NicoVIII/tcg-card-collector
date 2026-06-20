import inventory_planning/application/queries/get_preferences/ports
import inventory_planning/infrastructure/daos/preferences_dao

pub fn new() -> ports.GetPlanningPreferencesPort {
  ports.GetPlanningPreferencesPort(current: fn() {
    let #(default_sort, default_grouping) = preferences_dao.get()
    ports.PlanningPreferencesReadModel(default_sort:, default_grouping:)
  })
}
