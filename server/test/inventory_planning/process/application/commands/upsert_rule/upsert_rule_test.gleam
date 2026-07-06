import inventory_planning/application/commands/upsert_rule/handler
import inventory_planning/application/commands/upsert_rule/ports

// A fake that accepts every write and reports the normalized fields it was
// handed back through its (otherwise unused) error channel, so a test can assert
// the handler canonicalizes predicate, selector, and sort keys before persisting.
fn echoing_port() -> ports.UpsertInventoryRulePort {
  ports.UpsertInventoryRulePort(upsert_rule: fn(model) {
    Error(model.expression <> "|" <> model.selector <> "|" <> model.sort_keys)
  })
}

fn command(
  expression expression: String,
  selector selector: String,
  sort_keys sort_keys: String,
) -> handler.UpsertInventoryRuleCommand {
  handler.UpsertInventoryRuleCommand(
    id: "r1",
    location_name: "Bulk",
    expression: expression,
    position: 0,
    selector: selector,
    sort_keys: sort_keys,
  )
}

pub fn valid_rule_persists_canonicalized_fields_test() {
  // Legacy `set_code=M11` canonicalizes to `set_code in (m11)`; selector and
  // (empty) sort keys echo back unchanged.
  assert handler.execute(
      command(
        expression: "set_code=M11",
        selector: "first_per_oracle",
        sort_keys: "",
      ),
      echoing_port(),
    )
    == Error(ports.PersistenceFailed("set_code in (m11)|first_per_oracle|"))
}

pub fn sort_keys_are_trimmed_and_canonicalized_test() {
  assert handler.execute(
      command(
        expression: "set_code=m11",
        selector: "all",
        sort_keys: " name , set_code ",
      ),
      echoing_port(),
    )
    == Error(ports.PersistenceFailed("set_code in (m11)|all|name,set_code"))
}

pub fn unknown_selector_is_rejected_before_persistence_test() {
  assert handler.execute(
      command(
        expression: "set_code=m11",
        selector: "every_other_one",
        sort_keys: "",
      ),
      echoing_port(),
    )
    == Error(ports.InvalidSelector)
}

pub fn malformed_predicate_is_rejected_before_persistence_test() {
  assert handler.execute(
      command(expression: "rarity >= legendary", selector: "all", sort_keys: ""),
      echoing_port(),
    )
    == Error(ports.InvalidExpression)
}

pub fn unknown_sort_key_is_rejected_before_persistence_test() {
  assert handler.execute(
      command(expression: "set_code=m11", selector: "all", sort_keys: "power"),
      echoing_port(),
    )
    == Error(ports.InvalidSortKeys)
}
