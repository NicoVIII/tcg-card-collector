import gleam/result
import inventory_planning/application/queries/get_preferences/ports
import inventory_planning/infrastructure/daos/preferences_dao

pub fn new() -> ports.GetPlanningPreferencesPort {
  ports.GetPlanningPreferencesPort(current: fn() {
    use #(default_sort, default_grouping) <- result.map(preferences_dao.get())
    ports.PlanningPreferencesReadModel(default_sort:, default_grouping:)
  })
}
