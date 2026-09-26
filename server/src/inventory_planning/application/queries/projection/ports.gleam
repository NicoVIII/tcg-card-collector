import gleam/dict.{type Dict}
import gleam/option.{type Option}
import shared/domain/color_identity.{type ColorIdentity}
import shared/domain/mana_value.{type ManaValue}
import shared/domain/oracle_id.{type OracleId}
import shared/domain/rarity.{type Rarity}
import shared/domain/release_date.{type ReleaseDate}

// --- Read models ----------------------------------------------------------

// One card in a location's pull-list: the collection quantity placed here, plus
// the display attributes (empty strings when the catalog didn't know them).
pub type ProjectionCard {
  ProjectionCard(
    name: String,
    set_code: String,
    collector_number: String,
    finish: String,
    language: String,
    quantity: Int,
    color_identity: String,
    rarity: String,
    card_type: String,
  )
}

// One sort key's category value for a section (#138), the DSL token
// (`sort_spec.sort_key_to_string`) rather than the domain type — the same
// plain-string-until-the-codec convention as ProjectionCard's finish/rarity/
// card_type above. `first == last` means every card in the section shares
// that one value; a differing pair means the part is a merged range
// ("CMC 1-3", "A-E").
pub type ProjectionSectionPart {
  ProjectionSectionPart(key: String, first: String, last: String)
}

// A contiguous, divider-worthy run of a location's sorted cards. `parts` is
// empty when the location has no sort keys, or when nothing in it was worth
// dividing on; `card_count` is copies, not distinct cards.
pub type ProjectionSection {
  ProjectionSection(parts: List(ProjectionSectionPart), card_count: Int)
}

// A physical destination in cascade order. `rule_id` is the rule that claimed
// these cards, or empty for the bulk remainder. `sections` partitions `cards`
// exactly once, in order.
pub type ProjectionLocation {
  ProjectionLocation(
    location_name: String,
    rule_id: String,
    total_quantity: Int,
    cards: List(ProjectionCard),
    sections: List(ProjectionSection),
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
  SnapshotRow(
    set_code: String,
    collector_number: String,
    finish: String,
    language: String,
    quantity: Int,
  )
}

// The catalog's facts for one printing, already carried as the shared value
// types (ADR 0008); the raw type line is reduced to planning's CardType at the
// handler boundary because that reduction is planning policy.
pub type CatalogAttributes {
  CatalogAttributes(
    name: String,
    rarity: Rarity,
    oracle_id: Option(OracleId),
    color_identity: ColorIdentity,
    type_line: String,
    released_at: Option(ReleaseDate),
    cmc: Option(ManaValue),
    layout: Option(String),
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
/// from the catalog are simply absent from the returned dict; a read error
/// propagates rather than collapsing to "no attributes".
pub type CatalogAttributesPort =
  fn(List(#(String, String))) ->
    Result(Dict(#(String, String), CatalogAttributes), String)

pub type RulesPort =
  fn() -> Result(RulesModel, String)

// The catalog's metadata for one set: its release date (None when the catalog
// doesn't date it) and the parent set it hangs off (None for a root set); the
// handler resolves these into set-family facts.
pub type SetMetadataRow {
  SetMetadataRow(
    released_at: Option(ReleaseDate),
    parent_set_code: Option(String),
  )
}

// Batch lookup: set metadata by set code. Sets absent from the catalog are
// simply absent from the returned dict; a read error propagates rather than
// collapsing to "no metadata".
pub type SetMetadataPort =
  fn(List(String)) -> Result(Dict(String, SetMetadataRow), String)

pub type InventoryProjectionPorts {
  InventoryProjectionPorts(
    snapshot_rows: SnapshotRowsPort,
    catalog_attributes: CatalogAttributesPort,
    rules: RulesPort,
    set_metadata: SetMetadataPort,
  )
}
