import domain/inventory_planning/rule_expression.{type RuleExpression}
import gleam/list
import gleam/option.{type Option}

pub type InventoryRule {
  InventoryRule(location_name: String, expression: RuleExpression)
}

pub fn location_for(
  rules: List(InventoryRule),
  set_code: String,
) -> Option(String) {
  list.find_map(rules, fn(rule) {
    case rule_expression.matches(rule.expression, set_code) {
      True -> Ok(rule.location_name)
      False -> Error(Nil)
    }
  })
  |> option.from_result
}
