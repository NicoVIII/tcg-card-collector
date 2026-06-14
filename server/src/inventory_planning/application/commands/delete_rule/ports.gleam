pub type DeleteInventoryRulePort {
  DeleteInventoryRulePort(delete_rule: fn(String) -> Nil)
}

pub type DeleteInventoryRuleError {
  DeleteInventoryRuleError(message: String)
}
