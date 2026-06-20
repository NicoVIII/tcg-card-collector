import inventory_planning/application/commands/upsert_rule/ports as upsert_rule_ports
import skir/skirout/inventory_planning/commands as inventory_planning_commands
import skir_client/service

pub fn map_upsert_inventory_rule_result(
  result: Result(Nil, upsert_rule_ports.UpsertInventoryRuleError),
) -> Result(
  inventory_planning_commands.UpsertInventoryRuleResponse,
  service.ServiceError,
) {
  case result {
    Ok(_) -> Ok(inventory_planning_commands.UpsertInventoryRuleResponseSuccess)
    Error(_) ->
      Error(service.ServiceError(
        service.E400xBadRequest,
        "invalid inventory rule expression",
      ))
  }
}
