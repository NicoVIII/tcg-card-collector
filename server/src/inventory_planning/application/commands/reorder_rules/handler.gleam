import gleam/list
import gleam/result
import gleam/string
import inventory_planning/application/commands/reorder_rules/ports
import shared/application/command_result

pub type ReorderInventoryRulesCommand {
  ReorderInventoryRulesCommand(ordered_ids: List(String))
}

pub fn execute(
  command: ReorderInventoryRulesCommand,
  ports: ports.ReorderInventoryRulesPorts,
) -> command_result.CommandResult(ports.ReorderInventoryRulesError) {
  let ReorderInventoryRulesCommand(ordered_ids: ordered_ids) = command

  use existing_ids <- result.try(
    ports.list_rule_ids()
    |> result.map_error(ports.PersistenceFailed),
  )

  case is_permutation_of(ordered_ids, existing_ids) {
    False -> Error(ports.NotAPermutation)
    True ->
      ports.set_positions(numbered(ordered_ids))
      |> result.map_error(ports.PersistenceFailed)
  }
}

// A sorted-list comparison catches every way the request can fail to name
// exactly the existing rules once each: a missing id, an unknown id, or a
// duplicate (which shifts the sorted list's length or contents).
fn is_permutation_of(
  ordered_ids: List(String),
  existing_ids: List(String),
) -> Bool {
  list.sort(ordered_ids, string.compare)
  == list.sort(existing_ids, string.compare)
}

fn numbered(ordered_ids: List(String)) -> List(ports.RulePosition) {
  ordered_ids
  |> list.index_map(fn(id, position) { ports.RulePosition(id:, position:) })
}
