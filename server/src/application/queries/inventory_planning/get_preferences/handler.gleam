import application/queries/inventory_planning/get_preferences/ports

pub type GetPlanningPreferencesQuery {
  GetPlanningPreferencesQuery
}

pub fn execute(
  _query: GetPlanningPreferencesQuery,
  port: ports.GetPlanningPreferencesPort,
) -> ports.PlanningPreferencesReadModel {
  port.current()
}
