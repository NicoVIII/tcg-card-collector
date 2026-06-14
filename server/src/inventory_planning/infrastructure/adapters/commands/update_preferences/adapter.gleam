import inventory_planning/application/commands/update_preferences/ports
import inventory_planning/infrastructure/stores/preferences_store

pub fn new() -> ports.UpdatePlanningPreferencesPort {
  ports.UpdatePlanningPreferencesPort(update: fn(prefs) {
    let ports.PlanningPreferencesWriteModel(
      default_sort: default_sort,
      default_grouping: default_grouping,
    ) = prefs
    preferences_store.update(default_sort, default_grouping)
  })
}
