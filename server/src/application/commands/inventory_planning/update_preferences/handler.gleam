import application/commands/command_result
import application/commands/inventory_planning/update_preferences/ports

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
