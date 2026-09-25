import gleam/option.{type Option}
import portability/domain/export_document.{
  type BulkSpec, type CollectionEntry, type PlacedEntry, type Rule,
}
import portability/domain/import_document.{type Section}

pub type ReplaceCollectionPort =
  fn(List(CollectionEntry)) -> Result(Nil, String)

pub type ReplaceTargetSetsPort =
  fn(List(String)) -> Result(Nil, String)

/// Replaces whichever of rules/bulk/placed are `Some`, atomically together
/// — a `None` part is left untouched (ADR 0019).
pub type ReplacePlanPort =
  fn(Option(List(Rule)), Option(BulkSpec), Option(List(PlacedEntry))) ->
    Result(Nil, String)

pub type CheckRulePort =
  fn(Rule) -> Result(Nil, String)

pub type CheckSortKeysPort =
  fn(String) -> Result(Nil, String)

pub type ImportDataPorts {
  ImportDataPorts(
    check_rule: CheckRulePort,
    check_sort_keys: CheckSortKeysPort,
    replace_target_sets: ReplaceTargetSetsPort,
    replace_plan: ReplacePlanPort,
    replace_collection: ReplaceCollectionPort,
  )
}

pub type ImportDataError {
  NothingToImport
  PersistenceFailed(reason: String)
  /// A later section's write failed after earlier ones already committed
  /// their own transaction (ADR 0019: each section replaces atomically on
  /// its own, in a fixed order) — `written` names exactly which sections
  /// took effect, so the caller can say what's left inconsistent.
  PartiallyWritten(written: List(Section), reason: String)
}
