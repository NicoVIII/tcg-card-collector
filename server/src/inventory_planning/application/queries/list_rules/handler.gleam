import inventory_planning/application/queries/list_rules/ports

pub type ListInventoryRulesQuery {
  ListInventoryRulesQuery
}

pub fn execute(
  _query: ListInventoryRulesQuery,
  port: ports.ListInventoryRulesPort,
) -> List(ports.InventoryRuleReadModel) {
  port.list_rules()
}
