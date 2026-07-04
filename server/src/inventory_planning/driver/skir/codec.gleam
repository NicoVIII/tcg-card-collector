import inventory_planning/application/commands/delete_rule/ports as delete_rule_ports
import inventory_planning/application/commands/update_bulk_spec/ports as update_bulk_spec_ports
import inventory_planning/application/commands/update_preferences/ports as update_preferences_ports
import inventory_planning/application/commands/upsert_rule/ports as upsert_rule_ports
import shared/driver/skir/skirout/inventory_planning/commands as inventory_planning_commands
import skir_client/service

pub fn map_upsert_inventory_rule_result(
  result: Result(Nil, upsert_rule_ports.UpsertInventoryRuleError),
) -> Result(
  inventory_planning_commands.UpsertInventoryRuleResponse,
  service.ServiceError,
) {
  case result {
    Ok(_) -> Ok(inventory_planning_commands.UpsertInventoryRuleResponseSuccess)
    Error(upsert_rule_ports.InvalidExpression) ->
      Error(service.ServiceError(
        service.E400xBadRequest,
        "invalid inventory rule expression",
      ))
    Error(upsert_rule_ports.InvalidSelector) ->
      Error(service.ServiceError(
        service.E400xBadRequest,
        "invalid inventory rule selector",
      ))
    Error(upsert_rule_ports.PersistenceFailed(_)) ->
      Error(service.ServiceError(
        service.E500xInternalServerError,
        "failed to save inventory rule",
      ))
  }
}

pub fn map_update_bulk_spec_result(
  result: Result(Nil, update_bulk_spec_ports.UpdateBulkSpecError),
) -> Result(
  inventory_planning_commands.UpdateBulkSpecResponse,
  service.ServiceError,
) {
  case result {
    Ok(_) -> Ok(inventory_planning_commands.UpdateBulkSpecResponseSuccess)
    Error(update_bulk_spec_ports.InvalidSortKeys) ->
      Error(service.ServiceError(
        service.E400xBadRequest,
        "invalid bulk sort keys",
      ))
    Error(update_bulk_spec_ports.PersistenceFailed(_)) ->
      Error(service.ServiceError(
        service.E500xInternalServerError,
        "failed to save bulk spec",
      ))
  }
}

pub fn map_delete_inventory_rule_result(
  result: Result(Nil, delete_rule_ports.DeleteInventoryRuleError),
) -> Result(
  inventory_planning_commands.DeleteInventoryRuleResponse,
  service.ServiceError,
) {
  case result {
    Ok(_) -> Ok(inventory_planning_commands.DeleteInventoryRuleResponseSuccess)
    Error(_) ->
      Error(service.ServiceError(
        service.E500xInternalServerError,
        "failed to delete inventory rule",
      ))
  }
}

pub fn map_update_preferences_result(
  result: Result(Nil, update_preferences_ports.UpdatePlanningPreferencesError),
) -> Result(
  inventory_planning_commands.UpdatePlanningPreferencesResponse,
  service.ServiceError,
) {
  case result {
    Ok(_) ->
      Ok(inventory_planning_commands.UpdatePlanningPreferencesResponseSuccess)
    Error(update_preferences_ports.InvalidPreferences) ->
      Error(service.ServiceError(service.E400xBadRequest, "invalid settings"))
    Error(update_preferences_ports.PersistenceFailed(_)) ->
      Error(service.ServiceError(
        service.E500xInternalServerError,
        "failed to save settings",
      ))
  }
}
