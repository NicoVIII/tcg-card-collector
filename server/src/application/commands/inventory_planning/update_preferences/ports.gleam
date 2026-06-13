pub type PlanningPreferencesWriteModel {
  PlanningPreferencesWriteModel(default_sort: String, default_grouping: String)
}

pub type UpdatePlanningPreferencesPort {
  UpdatePlanningPreferencesPort(
    update: fn(PlanningPreferencesWriteModel) -> Nil,
  )
}

pub type UpdatePlanningPreferencesError {
  UpdatePlanningPreferencesError(message: String)
}
