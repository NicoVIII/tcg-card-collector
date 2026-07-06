import gleam/dict.{type Dict}

// --- Read models ----------------------------------------------------------

// One card in a location's pull-list: the collection quantity placed here, plus
// the display attributes (empty strings when the catalog didn't know them).
pub type ProjectionCard {
  ProjectionCard(
    name: String,
    set_code: String,
    collector_number: String,
    quantity: Int,
    color_identity: String,
    rarity: String,
    card_type: String,
  )
}

// A physical destination in cascade order. `rule_id` is the rule that claimed
// these cards, or empty for the bulk remainder.
pub type ProjectionLocation {
  ProjectionLocation(
    location_name: String,
    rule_id: String,
    total_quantity: Int,
    cards: List(ProjectionCard),
  )
}

// The whole projection: locations in cascade order, the grand total of copies
// placed, and how many distinct collection keys the catalog couldn't identify.
pub type Projection {
  Projection(
    locations: List(ProjectionLocation),
    total_quantity: Int,
    unknown_count: Int,
  )
}

// --- Driven ports ---------------------------------------------------------

pub type SnapshotRow {
  SnapshotRow(set_code: String, collector_number: String, quantity: Int)
}

// The catalog's opaque metadata for one printing; planning parses these strings
// into value types at the handler boundary.
pub type CatalogAttributes {
  CatalogAttributes(
    name: String,
    rarity: String,
    oracle_id: String,
    color_identity: String,
    type_line: String,
    released_at: String,
  )
}

// A stored rule, still textual: `expression` is the predicate DSL, `selector`
// the copy-selector DSL, `sort_keys` the sort DSL, `location_name` the (possibly
// templated) target.
pub type RuleRow {
  RuleRow(
    id: String,
    position: Int,
    selector: String,
    expression: String,
    location_name: String,
    sort_keys: String,
  )
}

pub type BulkSpecRow {
  BulkSpecRow(location_name: String, sort_keys: String)
}

// The full cascade configuration: the ordered rules plus the bulk remainder.
pub type RulesModel {
  RulesModel(rules: List(RuleRow), bulk: BulkSpecRow)
}

pub type SnapshotRowsPort =
  fn() -> Result(List(SnapshotRow), String)

/// Batch lookup: catalog attributes by (set_code, collector_number). Keys absent
/// from the catalog are simply absent from the returned dict.
pub type CatalogAttributesPort =
  fn(List(#(String, String))) -> Dict(#(String, String), CatalogAttributes)

pub type RulesPort =
  fn() -> RulesModel

pub type SetReleaseDatesPort =
  fn(List(String)) -> Dict(String, String)

pub type InventoryProjectionPorts {
  InventoryProjectionPorts(
    snapshot_rows: SnapshotRowsPort,
    catalog_attributes: CatalogAttributesPort,
    rules: RulesPort,
    set_release_dates: SetReleaseDatesPort,
  )
}
