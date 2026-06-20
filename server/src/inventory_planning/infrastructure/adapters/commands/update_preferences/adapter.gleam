import inventory_planning/application/commands/update_preferences/ports
import inventory_planning/infrastructure/daos/preferences_dao

pub fn new() -> ports.UpdatePlanningPreferencesPort {
  ports.UpdatePlanningPreferencesPort(update: fn(prefs) {
    let ports.PlanningPreferencesWriteModel(
      default_sort: default_sort,
      default_grouping: default_grouping,
    ) = prefs
    preferences_dao.update(default_sort, default_grouping)
  })
}
