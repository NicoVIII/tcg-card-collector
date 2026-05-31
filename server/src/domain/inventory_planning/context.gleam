pub type InventoryPlanningTerm {
  InventoryRule
  InventoryLocation
  InventoryProjection
  GroupingStrategy
}

pub fn bounded_context_name() -> String {
  "inventory_planning"
}

pub fn ubiquitous_language() -> List(String) {
  [
    "InventoryRule",
    "InventoryLocation",
    "InventoryProjection",
    "GroupingStrategy",
  ]
}
