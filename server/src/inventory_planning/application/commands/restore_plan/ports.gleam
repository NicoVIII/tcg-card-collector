import gleam/option.{type Option}
import shared/domain/copy_key.{type CopyKey}

pub type RuleWriteModel {
  RuleWriteModel(
    id: String,
    location_name: String,
    expression: String,
    position: Int,
    selector: String,
    sort_keys: String,
  )
}

pub type BulkSpecWriteModel {
  BulkSpecWriteModel(location_name: String, sort_keys: String)
}

pub type PlacedWriteModel {
  PlacedWriteModel(key: CopyKey, location: String, quantity: Int)
}

/// Replaces whichever of rules/bulk/placed are `Some`, atomically together —
/// a `None` part is left untouched (ADR 0019: Portability's restore, one
/// context, one transaction).
pub type ReplacePlanPort =
  fn(
    Option(List(RuleWriteModel)),
    Option(BulkSpecWriteModel),
    Option(List(PlacedWriteModel)),
  ) -> Result(Nil, String)

pub type RestorePlanPorts {
  RestorePlanPorts(replace_plan: ReplacePlanPort)
}

pub type RestorePlanError {
  InvalidRules
  InvalidBulkSpec
  InvalidPlaced
  PersistenceFailed(reason: String)
}
