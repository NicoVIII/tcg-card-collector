pub type InventoryRuleWriteModel {
  InventoryRuleWriteModel(id: String, location_name: String, expression: String)
}

pub type InventoryRuleReadModel {
  InventoryRuleReadModel(id: String, location_name: String, expression: String)
}

pub type InventoryProjectionReadModel {
  InventoryProjectionReadModel(
    location_name: String,
    card_name: String,
    set_code: String,
    quantity: Int,
    group_value: String,
  )
}

pub type InventoryPlanningRepository {
  InventoryPlanningRepository(
    upsert_rule: fn(InventoryRuleWriteModel) -> Nil,
    list_rules: fn() -> List(InventoryRuleReadModel),
    delete_rule: fn(String) -> Nil,
    inventory_projection: fn(String, String) ->
      List(InventoryProjectionReadModel),
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

pub fn projection(
  repository: InventoryPlanningRepository,
  sort_by sort_by: String,
  group_by group_by: String,
) -> List(InventoryProjectionReadModel) {
  let InventoryPlanningRepository(
    inventory_projection: inventory_projection,
    ..,
  ) = repository
  inventory_projection(sort_by, group_by)
}
