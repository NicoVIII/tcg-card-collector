pub type PlanningPreferencesWriteModel {
  PlanningPreferencesWriteModel(default_sort: String, default_grouping: String)
}

pub type UpdatePlanningPreferencesPort {
  UpdatePlanningPreferencesPort(
    update: fn(PlanningPreferencesWriteModel) -> Result(Nil, String),
  )
}

pub type UpdatePlanningPreferencesError {
  InvalidPreferences
  PersistenceFailed(message: String)
}
