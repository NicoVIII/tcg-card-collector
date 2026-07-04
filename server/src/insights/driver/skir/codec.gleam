import insights/application/commands/mark_target_set/ports as mark_target_set_ports
import insights/application/commands/unmark_target_set/ports as unmark_target_set_ports
import shared/driver/skir/skirout/insights/commands as insights_commands
import skir_client/service

pub fn map_mark_target_set_result(
  result: Result(Nil, mark_target_set_ports.MarkTargetSetError),
) -> Result(insights_commands.MarkTargetSetResponse, service.ServiceError) {
  case result {
    Ok(_) -> Ok(insights_commands.MarkTargetSetResponseSuccess)
    Error(_) -> Ok(insights_commands.MarkTargetSetResponseError)
  }
}

pub fn map_unmark_target_set_result(
  result: Result(Nil, unmark_target_set_ports.UnmarkTargetSetError),
) -> Result(insights_commands.UnmarkTargetSetResponse, service.ServiceError) {
  case result {
    Ok(_) -> Ok(insights_commands.UnmarkTargetSetResponseSuccess)
    Error(_) -> Ok(insights_commands.UnmarkTargetSetResponseError)
  }
}
