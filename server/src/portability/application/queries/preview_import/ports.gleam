import portability/domain/export_document.{type BulkSpec, type Rule}

pub type CheckRulePort =
  fn(Rule) -> Result(Nil, String)

pub type CheckBulkSpecPort =
  fn(BulkSpec) -> Result(Nil, String)

pub type CheckManagedKindPort =
  fn(String) -> Result(Nil, String)

pub type PreviewImportPorts {
  PreviewImportPorts(
    check_rule: CheckRulePort,
    check_bulk_spec: CheckBulkSpecPort,
    check_managed_kind: CheckManagedKindPort,
  )
}
