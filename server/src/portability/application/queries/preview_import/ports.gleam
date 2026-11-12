import gleam/option.{type Option}
import portability/domain/export_document.{
  type BulkSpec, type CollectionEntry, type ManagedLocationEntry,
  type MemberEntry, type PlacedEntry, type Rule,
}
import portability/domain/import_document.{type LedgerPrune}

pub type CheckRulePort =
  fn(Rule) -> Result(Nil, String)

pub type CheckBulkSpecPort =
  fn(BulkSpec) -> Result(Nil, String)

pub type CheckManagedKindPort =
  fn(String) -> Result(Nil, String)

/// The ledger rows ReconcilePlacedLedger prunes right after an import that
/// writes this collection plus the given managed and placed sections (None:
/// absent from the file, so the current state stays).
pub type PredictPrunePort =
  fn(
    List(CollectionEntry),
    Option(#(List(ManagedLocationEntry), List(MemberEntry))),
    Option(List(PlacedEntry)),
  ) -> Result(List(LedgerPrune), String)

pub type PreviewImportPorts {
  PreviewImportPorts(
    check_rule: CheckRulePort,
    check_bulk_spec: CheckBulkSpecPort,
    check_managed_kind: CheckManagedKindPort,
    predict_prune: PredictPrunePort,
  )
}
