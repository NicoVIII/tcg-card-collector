import inventory_planning/domain/sort_spec.{type SortKey}

// The leftover (unclaimed) cards land in one bulk location, laid out by the
// shared sort-key vocabulary.
pub type BulkSpec {
  BulkSpec(location_name: String, sort_keys: List(SortKey))
}
