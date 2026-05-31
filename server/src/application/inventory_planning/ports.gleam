pub type InventoryRuleWriteModel {
  InventoryRuleWriteModel(id: String, location_name: String, expression: String)
}

pub type InventoryRuleReadModel {
  InventoryRuleReadModel(id: String, location_name: String, expression: String)
}

pub type InventoryPlanningRepository {
  InventoryPlanningRepository(
    upsert_rule: fn(InventoryRuleWriteModel) -> Nil,
    list_rules: fn() -> List(InventoryRuleReadModel),
    delete_rule: fn(String) -> Nil,
  )
}

pub fn upsert(
  repository: InventoryPlanningRepository,
  rule: InventoryRuleWriteModel,
) -> Nil {
  let InventoryPlanningRepository(upsert_rule: upsert_rule, ..) = repository
  upsert_rule(rule)
}

pub fn list(
  repository: InventoryPlanningRepository,
) -> List(InventoryRuleReadModel) {
  let InventoryPlanningRepository(list_rules: list_rules, ..) = repository
  list_rules()
}

pub fn delete(repository: InventoryPlanningRepository, rule_id: String) -> Nil {
  let InventoryPlanningRepository(delete_rule: delete_rule, ..) = repository
  delete_rule(rule_id)
}
