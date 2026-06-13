import application/commands/inventory_planning/update_preferences/ports
import infrastructure/stores/inventory_planning/preferences_store

pub fn new() -> ports.UpdatePlanningPreferencesPort {
  ports.UpdatePlanningPreferencesPort(update: fn(prefs) {
    let ports.PlanningPreferencesWriteModel(
      default_sort: default_sort,
      default_grouping: default_grouping,
    ) = prefs
    preferences_store.update(default_sort, default_grouping)
  })
}
