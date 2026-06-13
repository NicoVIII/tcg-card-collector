import application/commands/inventory_planning/delete_rule/handler as delete_rule_handler
import application/commands/inventory_planning/delete_rule/ports as delete_rule_ports
import application/commands/inventory_planning/update_preferences/handler as update_preferences_handler
import application/commands/inventory_planning/update_preferences/ports as update_preferences_ports
import application/commands/inventory_planning/upsert_rule/handler as upsert_rule_handler
import application/commands/inventory_planning/upsert_rule/ports as upsert_rule_ports
import application/queries/inventory_planning/get_preferences/handler as get_preferences_handler
import application/queries/inventory_planning/get_preferences/ports as get_preferences_ports
import application/queries/inventory_planning/list_rules/handler as list_rules_handler
import application/queries/inventory_planning/list_rules/ports as list_rules_ports
import application/queries/inventory_planning/projection/handler as projection_handler
import application/queries/inventory_planning/projection/ports as projection_ports
import domain/inventory_planning/grouping_strategy
import domain/inventory_planning/sort_strategy

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
  port: projection_ports.InventoryProjectionPort,
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
            port,
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
