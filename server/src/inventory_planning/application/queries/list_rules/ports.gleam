pub type InventoryRuleReadModel {
  InventoryRuleReadModel(
    id: String,
    location_name: String,
    expression: String,
    position: Int,
    selector: String,
  )
}

pub type ListInventoryRulesPort {
  ListInventoryRulesPort(list_rules: fn() -> List(InventoryRuleReadModel))
}
