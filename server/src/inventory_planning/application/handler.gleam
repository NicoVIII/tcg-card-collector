import inventory_planning/application/commands/delete_rule/handler as delete_rule_handler
import inventory_planning/application/commands/delete_rule/ports as delete_rule_ports
import inventory_planning/application/commands/update_preferences/handler as update_preferences_handler
import inventory_planning/application/commands/update_preferences/ports as update_preferences_ports
import inventory_planning/application/commands/upsert_rule/handler as upsert_rule_handler
import inventory_planning/application/commands/upsert_rule/ports as upsert_rule_ports
import inventory_planning/application/queries/get_preferences/handler as get_preferences_handler
import inventory_planning/application/queries/get_preferences/ports as get_preferences_ports
import inventory_planning/application/queries/list_rules/handler as list_rules_handler
import inventory_planning/application/queries/list_rules/ports as list_rules_ports
import inventory_planning/application/queries/projection/handler as projection_handler
import inventory_planning/application/queries/projection/ports as projection_ports
import inventory_planning/domain/grouping_strategy
import inventory_planning/domain/sort_strategy

pub type InventoryProjectionError {
  InvalidSortBy
  InvalidGroupBy
}

pub fn upsert_inventory_rule(
  port: upsert_rule_ports.UpsertInventoryRulePort,
  id: String,
  location_name: String,
  expression: String,
) -> Result(Nil, upsert_rule_ports.UpsertInventoryRuleError) {
  upsert_rule_handler.execute(
    upsert_rule_handler.UpsertInventoryRuleCommand(
      id: id,
      location_name: location_name,
      expression: expression,
    ),
    port,
  )
}

pub fn delete_inventory_rule(
  port: delete_rule_ports.DeleteInventoryRulePort,
  id: String,
) -> Nil {
  let _ =
    delete_rule_handler.execute(
      delete_rule_handler.DeleteInventoryRuleCommand(id: id),
      port,
    )
  Nil
}

pub fn list_inventory_rules(
  port: list_rules_ports.ListInventoryRulesPort,
) -> List(list_rules_ports.InventoryRuleReadModel) {
  list_rules_handler.execute(list_rules_handler.ListInventoryRulesQuery, port)
}

pub fn inventory_projection(
  ports: projection_ports.InventoryProjectionPorts,
  raw_sort_by: String,
  raw_group_by: String,
) -> Result(
  List(projection_ports.InventoryProjectionReadModel),
  InventoryProjectionError,
) {
  case sort_strategy.parse(raw_sort_by) {
    Error(_) -> Error(InvalidSortBy)
    Ok(sort_by) ->
      case grouping_strategy.parse(raw_group_by) {
        Error(_) -> Error(InvalidGroupBy)
        Ok(group_by) ->
          Ok(projection_handler.execute(
            projection_handler.InventoryProjectionQuery(sort_by:, group_by:),
            ports,
          ))
      }
  }
}

pub fn get_planning_preferences(
  port: get_preferences_ports.GetPlanningPreferencesPort,
) -> get_preferences_ports.PlanningPreferencesReadModel {
  get_preferences_handler.execute(
    get_preferences_handler.GetPlanningPreferencesQuery,
    port,
  )
}

pub fn update_planning_preferences(
  port: update_preferences_ports.UpdatePlanningPreferencesPort,
  default_sort: String,
  default_grouping: String,
) -> Nil {
  let _ =
    update_preferences_handler.execute(
      update_preferences_handler.UpdatePlanningPreferencesCommand(
        default_sort: default_sort,
        default_grouping: default_grouping,
      ),
      port,
    )
  Nil
}
