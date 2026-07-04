import insights/application/commands/mark_target_set/ports as mark_target_set_ports
import insights/application/commands/unmark_target_set/ports as unmark_target_set_ports
import insights/driver/skir/codec as insights_skir_codec
import shared/driver/skir/skirout/insights/commands as insights_commands

pub fn mark_ok_maps_to_success_test() {
  assert insights_skir_codec.map_mark_target_set_result(Ok(Nil))
    == Ok(insights_commands.MarkTargetSetResponseSuccess)
}

pub fn mark_invalid_set_code_maps_to_error_test() {
  assert insights_skir_codec.map_mark_target_set_result(Error(
      mark_target_set_ports.InvalidSetCode,
    ))
    == Ok(insights_commands.MarkTargetSetResponseError)
}

pub fn unmark_ok_maps_to_success_test() {
  assert insights_skir_codec.map_unmark_target_set_result(Ok(Nil))
    == Ok(insights_commands.UnmarkTargetSetResponseSuccess)
}

pub fn unmark_persistence_failure_maps_to_error_test() {
  assert insights_skir_codec.map_unmark_target_set_result(
      Error(unmark_target_set_ports.PersistenceFailed("disk full")),
    )
    == Ok(insights_commands.UnmarkTargetSetResponseError)
}
