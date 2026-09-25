import portability/domain/export_document.{type CollectionEntry}
import portability/domain/import_document.{type Section}

pub type ReplaceCollectionPort =
  fn(List(CollectionEntry)) -> Result(Nil, String)

pub type ReplaceTargetSetsPort =
  fn(List(String)) -> Result(Nil, String)

pub type ImportDataPorts {
  ImportDataPorts(
    replace_collection: ReplaceCollectionPort,
    replace_target_sets: ReplaceTargetSetsPort,
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
