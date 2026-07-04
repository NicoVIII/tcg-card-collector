pub type InventoryRuleWriteModel {
  InventoryRuleWriteModel(
    id: String,
    location_name: String,
    expression: String,
    position: Int,
    selector: String,
  )
}

pub type UpsertInventoryRulePort {
  UpsertInventoryRulePort(
    upsert_rule: fn(InventoryRuleWriteModel) -> Result(Nil, String),
  )
}

pub type UpsertInventoryRuleError {
  InvalidExpression
  InvalidSelector
  PersistenceFailed(reason: String)
}
