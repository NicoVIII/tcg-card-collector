pub type InventoryRuleWriteModel {
  InventoryRuleWriteModel(
    id: String,
    location_name: String,
    expression: String,
    position: Int,
    selector: String,
    sort_keys: String,
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
  InvalidSortKeys
  PersistenceFailed(reason: String)
}
