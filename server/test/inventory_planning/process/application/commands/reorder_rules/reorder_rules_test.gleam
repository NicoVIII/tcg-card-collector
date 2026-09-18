import inventory_planning/application/commands/reorder_rules/handler
import inventory_planning/application/commands/reorder_rules/ports
import support/ref

fn build_ports(
  existing_ids existing_ids: List(String),
  saved saved: ref.Ref(List(ports.RulePosition)),
) -> ports.ReorderInventoryRulesPorts {
  ports.ReorderInventoryRulesPorts(
    list_rule_ids: fn() { Ok(existing_ids) },
    set_positions: fn(positions) {
      ref.set(saved, positions)
      Ok(Nil)
    },
  )
}

fn command(ordered_ids: List(String)) -> handler.ReorderInventoryRulesCommand {
  handler.ReorderInventoryRulesCommand(ordered_ids: ordered_ids)
}

pub fn reversal_renumbers_contiguously_from_zero_test() {
  let saved = ref.new([])
  let inventory_ports = build_ports(existing_ids: ["a", "b", "c"], saved:)

  let result = handler.execute(command(["c", "b", "a"]), inventory_ports)

  assert result == Ok(Nil)
  assert ref.get(saved)
    == [
      ports.RulePosition(id: "c", position: 0),
      ports.RulePosition(id: "b", position: 1),
      ports.RulePosition(id: "a", position: 2),
    ]
}

pub fn missing_id_is_rejected_without_writing_test() {
  let saved = ref.new([])
  let inventory_ports = build_ports(existing_ids: ["a", "b"], saved:)

  let result = handler.execute(command(["a"]), inventory_ports)

  assert result == Error(ports.NotAPermutation)
  assert ref.get(saved) == []
}

pub fn unknown_id_is_rejected_without_writing_test() {
  let saved = ref.new([])
  let inventory_ports = build_ports(existing_ids: ["a", "b"], saved:)

  let result = handler.execute(command(["a", "z"]), inventory_ports)

  assert result == Error(ports.NotAPermutation)
  assert ref.get(saved) == []
}

pub fn duplicated_id_is_rejected_without_writing_test() {
  let saved = ref.new([])
  let inventory_ports = build_ports(existing_ids: ["a", "b"], saved:)

  let result = handler.execute(command(["a", "a"]), inventory_ports)

  assert result == Error(ports.NotAPermutation)
  assert ref.get(saved) == []
}

pub fn empty_rules_and_empty_request_succeeds_test() {
  let saved = ref.new([])
  let inventory_ports = build_ports(existing_ids: [], saved:)

  let result = handler.execute(command([]), inventory_ports)

  assert result == Ok(Nil)
  assert ref.get(saved) == []
}

pub fn persistence_failure_is_reported_test() {
  let inventory_ports =
    ports.ReorderInventoryRulesPorts(
      list_rule_ids: fn() { Ok(["a"]) },
      set_positions: fn(_positions) { Error("db down") },
    )

  let result = handler.execute(command(["a"]), inventory_ports)

  assert result == Error(ports.PersistenceFailed("db down"))
}
