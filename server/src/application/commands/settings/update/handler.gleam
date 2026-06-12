import application/commands/command_result
import application/commands/settings/update/ports

pub type UpdateSettingsCommand {
  UpdateSettingsCommand(default_sort: String, default_grouping: String)
}

pub fn execute(
  command: UpdateSettingsCommand,
  port: ports.UpdateSettingsPort,
) -> command_result.CommandResult(ports.UpdateSettingsError) {
  let UpdateSettingsCommand(
    default_sort: default_sort,
    default_grouping: default_grouping,
  ) = command
  port.update(ports.AppSettingsWriteModel(
    default_sort: default_sort,
    default_grouping: default_grouping,
  ))
  Ok(Nil)
}
