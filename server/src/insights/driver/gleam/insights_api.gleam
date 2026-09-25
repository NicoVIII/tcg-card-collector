import insights/application/commands/replace_target_sets/handler as replace_target_sets_handler
import insights/application/commands/replace_target_sets/ports as replace_target_sets_ports

// nolint: depends_only_on -- glinter_arch doesn't yet allow Driver->own-BC-Infrastructure, though AGENTS.md documents it; fixing needs a gleam-libs change
import insights/infrastructure/adapters/commands/replace_target_sets/adapter as replace_target_sets_adapter

// nolint: depends_only_on -- glinter_arch doesn't yet allow Driver->own-BC-Infrastructure, though AGENTS.md documents it; fixing needs a gleam-libs change
import insights/infrastructure/daos/insights_dao

/// Every set code the collection is tracked toward completion for, in the
/// table's own order (ADR 0019: Portability sorts on its own side). A plain
/// read with no computation between the table and this list, so it skips a
/// dedicated query handler the way MarkTargetSet/UnmarkTargetSet's own reads
/// do — SetCompletionQuery goes through the same DAO call.
pub fn list_target_sets() -> Result(List(String), String) {
  insights_dao.list()
}

/// Replaces every target set with the given codes, reusing
/// ReplaceTargetSets' all-or-nothing validation and persistence — the
/// caller (Portability) already holds codes it filtered at the document
/// level (ADR 0019), so this is defense-in-depth, not a caller-facing
/// filter.
pub fn replace_target_sets(set_codes: List(String)) -> Result(Nil, String) {
  case
    replace_target_sets_handler.execute(
      replace_target_sets_handler.ReplaceTargetSetsCommand(set_codes:),
      replace_target_sets_adapter.new(),
    )
  {
    Ok(Nil) -> Ok(Nil)
    Error(replace_target_sets_ports.InvalidSetCodes) ->
      Error("invalid set codes")
    Error(replace_target_sets_ports.PersistenceFailed(reason)) -> Error(reason)
  }
}
