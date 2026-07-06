import gleam/result
import inventory_planning/application/commands/update_bulk_spec/ports
import inventory_planning/domain/sort_spec
import shared/application/command_result

pub type UpdateBulkSpecCommand {
  UpdateBulkSpecCommand(location_name: String, sort_keys: String)
}

pub fn execute(
  command: UpdateBulkSpecCommand,
  port: ports.UpdateBulkSpecPort,
) -> command_result.CommandResult(ports.UpdateBulkSpecError) {
  let UpdateBulkSpecCommand(location_name: location_name, sort_keys: sort_keys) =
    command

  use keys <- result.try(
    sort_spec.parse_sort_keys(sort_keys)
    |> result.replace_error(ports.InvalidSortKeys),
  )

  port.update(ports.BulkSpecWriteModel(
    location_name: location_name,
    sort_keys: sort_spec.sort_keys_to_string(keys),
  ))
  |> result.map_error(ports.PersistenceFailed)
}
