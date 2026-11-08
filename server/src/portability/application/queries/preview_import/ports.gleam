import portability/domain/export_document.{type Rule}

pub type CheckRulePort =
  fn(Rule) -> Result(Nil, String)

pub type CheckSortKeysPort =
  fn(String) -> Result(Nil, String)

pub type CheckManagedKindPort =
  fn(String) -> Result(Nil, String)

pub type PreviewImportPorts {
  PreviewImportPorts(
    check_rule: CheckRulePort,
    check_sort_keys: CheckSortKeysPort,
    check_managed_kind: CheckManagedKindPort,
  )
}
