import application/command_result
import inventory_planning/application/commands/update_preferences/ports

pub type UpdatePlanningPreferencesCommand {
  UpdatePlanningPreferencesCommand(
    default_sort: String,
    default_grouping: String,
  )
}

pub fn execute(
  command: UpdatePlanningPreferencesCommand,
  port: ports.UpdatePlanningPreferencesPort,
) -> command_result.CommandResult(ports.UpdatePlanningPreferencesError) {
  let UpdatePlanningPreferencesCommand(
    default_sort: default_sort,
    default_grouping: default_grouping,
  ) = command
  port.update(ports.PlanningPreferencesWriteModel(
    default_sort: default_sort,
    default_grouping: default_grouping,
  ))
  Ok(Nil)
}
