pub type InventoryProjectionReadModel {
  InventoryProjectionReadModel(
    location_name: String,
    card_name: String,
    set_code: String,
    quantity: Int,
    group_value: String,
  )
}

pub type InventoryProjectionPort {
  InventoryProjectionPort(
    projection: fn(String, String) -> List(InventoryProjectionReadModel),
  )
}
