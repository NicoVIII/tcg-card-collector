import inventory_planning/application/commands/upsert_rule/handler
import inventory_planning/application/commands/upsert_rule/ports

// A fake that accepts every write and reports the normalized expression it was
// handed back through its (otherwise unused) error channel, so a test can assert
// the handler canonicalizes the predicate before persisting.
fn echoing_port() -> ports.UpsertInventoryRulePort {
  ports.UpsertInventoryRulePort(upsert_rule: fn(model) {
    Error(model.expression <> "|" <> model.selector)
  })
}

fn command(
  expression expression: String,
  selector selector: String,
) -> handler.UpsertInventoryRuleCommand {
  handler.UpsertInventoryRuleCommand(
    id: "r1",
    location_name: "Bulk",
    expression: expression,
    position: 0,
    selector: selector,
  )
}

pub fn valid_rule_persists_canonicalized_predicate_and_selector_test() {
  // Legacy `set_code=M11` canonicalizes to `set_code in (m11)`; selector echoes.
  assert handler.execute(
      command(expression: "set_code=M11", selector: "first_per_oracle"),
      echoing_port(),
    )
    == Error(ports.PersistenceFailed("set_code in (m11)|first_per_oracle"))
}

pub fn unknown_selector_is_rejected_before_persistence_test() {
  assert handler.execute(
      command(expression: "set_code=m11", selector: "every_other_one"),
      echoing_port(),
    )
    == Error(ports.InvalidSelector)
}

pub fn malformed_predicate_is_rejected_before_persistence_test() {
  assert handler.execute(
      command(expression: "rarity >= legendary", selector: "all"),
      echoing_port(),
    )
    == Error(ports.InvalidExpression)
}
