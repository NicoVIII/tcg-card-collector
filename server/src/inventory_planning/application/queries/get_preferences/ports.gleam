pub type PlanningPreferencesReadModel {
  PlanningPreferencesReadModel(default_sort: String, default_grouping: String)
}

pub type GetPlanningPreferencesPort {
  GetPlanningPreferencesPort(
    current: fn() -> Result(PlanningPreferencesReadModel, String),
  )
}
