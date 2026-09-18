/// One rule's place in the renumbered cascade.
pub type RulePosition {
  RulePosition(id: String, position: Int)
}

pub type ReorderInventoryRulesPorts {
  ReorderInventoryRulesPorts(
    list_rule_ids: fn() -> Result(List(String), String),
    set_positions: fn(List(RulePosition)) -> Result(Nil, String),
  )
}

pub type ReorderInventoryRulesError {
  /// The request's ids don't name exactly the existing rules once each
  /// (missing, duplicated, or unknown id).
  NotAPermutation
  PersistenceFailed(reason: String)
}
