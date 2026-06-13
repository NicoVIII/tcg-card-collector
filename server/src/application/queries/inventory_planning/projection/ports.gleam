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

pub type InventoryProjectionPort {
  InventoryProjectionPort(
    snapshot_rows: fn() -> List(SnapshotRow),
    catalog_name: fn(String, String) -> Option(String),
    rules: fn() -> List(RuleRow),
  )
}
