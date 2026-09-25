import inventory_planning/driver/gleam/inventory_planning_api
import portability/application/queries/preview_import/ports
import portability/domain/export_document.{type Rule}

pub fn new() -> ports.PreviewImportPorts {
  ports.PreviewImportPorts(
    check_rule: check_rule_adapter,
    check_sort_keys: inventory_planning_api.check_sort_keys,
  )
}

fn check_rule_adapter(rule: Rule) -> Result(Nil, String) {
  inventory_planning_api.check_rule(inventory_planning_api.RuleSpec(
    location: rule.location,
    expression: rule.expression,
    selector: rule.selector,
    sort_keys: rule.sort_keys,
  ))
}
