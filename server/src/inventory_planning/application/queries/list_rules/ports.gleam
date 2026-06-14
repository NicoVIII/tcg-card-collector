pub type InventoryRuleReadModel {
  InventoryRuleReadModel(id: String, location_name: String, expression: String)
}

pub type ListInventoryRulesPort {
  ListInventoryRulesPort(list_rules: fn() -> List(InventoryRuleReadModel))
}
