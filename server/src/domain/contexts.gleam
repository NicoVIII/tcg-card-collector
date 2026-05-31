pub type BoundedContext {
  CardCatalog
  CollectionImport
  InventoryPlanning
}

pub fn all() -> List(BoundedContext) {
  [CardCatalog, CollectionImport, InventoryPlanning]
}

pub fn name(context: BoundedContext) -> String {
  case context {
    CardCatalog -> "card_catalog"
    CollectionImport -> "collection_import"
    InventoryPlanning -> "inventory_planning"
  }
}
