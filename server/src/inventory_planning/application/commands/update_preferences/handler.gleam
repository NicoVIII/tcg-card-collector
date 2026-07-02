import gleam/result
import inventory_planning/application/commands/update_preferences/ports
import inventory_planning/domain/grouping_strategy
import inventory_planning/domain/sort_strategy
import shared/application/command_result

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

  use sort <- result.try(
    sort_strategy.parse(default_sort)
    |> result.map_error(fn(_) { ports.InvalidPreferences }),
  )
  use grouping <- result.try(
    grouping_strategy.parse(default_grouping)
    |> result.map_error(fn(_) { ports.InvalidPreferences }),
  )

  port.update(ports.PlanningPreferencesWriteModel(
    default_sort: sort_strategy.to_string(sort),
    default_grouping: grouping_strategy.to_string(grouping),
  ))
  |> result.map_error(ports.PersistenceFailed)
}
