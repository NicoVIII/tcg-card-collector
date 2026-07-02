import inventory_planning/application/commands/delete_rule/ports as delete_rule_ports
import inventory_planning/application/commands/update_preferences/ports as update_preferences_ports
import inventory_planning/application/commands/upsert_rule/ports as upsert_rule_ports
import inventory_planning/driver/skir/codec as inventory_planning_skir_codec
import shared/driver/skir/skirout/inventory_planning/commands as inventory_planning_commands
import skir_client/service

pub fn upsert_ok_maps_to_success_test() {
  assert inventory_planning_skir_codec.map_upsert_inventory_rule_result(Ok(Nil))
    == Ok(inventory_planning_commands.UpsertInventoryRuleResponseSuccess)
}

pub fn upsert_invalid_expression_maps_to_bad_request_test() {
  assert inventory_planning_skir_codec.map_upsert_inventory_rule_result(Error(
      upsert_rule_ports.InvalidExpression,
    ))
    == Error(service.ServiceError(
      service.E400xBadRequest,
      "invalid inventory rule expression",
    ))
}

pub fn delete_ok_maps_to_success_test() {
  assert inventory_planning_skir_codec.map_delete_inventory_rule_result(Ok(Nil))
    == Ok(inventory_planning_commands.DeleteInventoryRuleResponseSuccess)
}

pub fn delete_failure_maps_to_internal_server_error_test() {
  assert inventory_planning_skir_codec.map_delete_inventory_rule_result(
      Error(delete_rule_ports.DeleteInventoryRuleError("disk full")),
    )
    == Error(service.ServiceError(
      service.E500xInternalServerError,
      "failed to delete inventory rule",
    ))
}

pub fn update_preferences_ok_maps_to_success_test() {
  assert inventory_planning_skir_codec.map_update_preferences_result(Ok(Nil))
    == Ok(inventory_planning_commands.UpdatePlanningPreferencesResponseSuccess)
}

pub fn update_preferences_invalid_maps_to_bad_request_test() {
  assert inventory_planning_skir_codec.map_update_preferences_result(Error(
      update_preferences_ports.InvalidPreferences,
    ))
    == Error(service.ServiceError(service.E400xBadRequest, "invalid settings"))
}

pub fn update_preferences_persistence_failure_maps_to_internal_server_error_test() {
  assert inventory_planning_skir_codec.map_update_preferences_result(
      Error(update_preferences_ports.PersistenceFailed("disk full")),
    )
    == Error(service.ServiceError(
      service.E500xInternalServerError,
      "failed to save settings",
    ))
}
