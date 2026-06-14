import gleam/option.{type Option}

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
  fn() -> List(SnapshotRow)

pub type CatalogNamePort =
  fn(String, String) -> Option(String)

pub type RulesPort =
  fn() -> List(RuleRow)

pub type InventoryProjectionPorts {
  InventoryProjectionPorts(
    snapshot_rows: SnapshotRowsPort,
    catalog_name: CatalogNamePort,
    rules: RulesPort,
  )
}
