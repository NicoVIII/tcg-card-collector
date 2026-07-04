import gleam/dict.{type Dict}

pub type InventoryProjectionReadModel {
  InventoryProjectionReadModel(
    location_name: String,
    card_name: String,
    set_code: String,
    quantity: Int,
    group_value: String,
  )
}

pub type SnapshotRow {
  SnapshotRow(set_code: String, collector_number: String, quantity: Int)
}

pub type RuleRow {
  RuleRow(location_name: String, expression: String)
}

pub type SnapshotRowsPort =
  fn() -> Result(List(SnapshotRow), String)

/// Batch lookup: card name by (set_code, collector_number). Keys absent from
/// the catalog are simply absent from the returned dict.
pub type CatalogNamesPort =
  fn(List(#(String, String))) -> Dict(#(String, String), String)

pub type RulesPort =
  fn() -> List(RuleRow)

pub type InventoryProjectionPorts {
  InventoryProjectionPorts(
    snapshot_rows: SnapshotRowsPort,
    catalog_names: CatalogNamesPort,
    rules: RulesPort,
  )
}
