pub type DeleteInventoryRulePort {
  DeleteInventoryRulePort(delete_rule: fn(String) -> Result(Nil, String))
}

pub type DeleteInventoryRuleError {
  DeleteInventoryRuleError(message: String)
}
