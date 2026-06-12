pub type InventoryRuleWriteModel {
  InventoryRuleWriteModel(id: String, location_name: String, expression: String)
}

pub type UpsertInventoryRulePort {
  UpsertInventoryRulePort(upsert_rule: fn(InventoryRuleWriteModel) -> Nil)
}

pub type UpsertInventoryRuleError {
  InvalidExpression
}
