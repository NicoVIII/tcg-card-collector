import application/inventory_planning/ports

pub fn new() -> ports.InventoryPlanningRepository {
  ports.InventoryPlanningRepository(
    upsert_rule: fn(_rule) { Nil },
    list_rules: fn() { [] },
    delete_rule: fn(_rule_id) { Nil },
  )
}
