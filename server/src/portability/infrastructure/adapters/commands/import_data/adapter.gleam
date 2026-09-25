import collection/driver/gleam/collection_api
import gleam/list
import gleam/option
import insights/driver/gleam/insights_api
import inventory_planning/driver/gleam/inventory_planning_api
import portability/application/commands/import_data/ports
import portability/domain/export_document.{
  type BulkSpec, type CollectionEntry, type PlacedEntry, type Rule,
}

/// Wraps each context's own driver/gleam facade (ADR 0019: Portability
/// reads/writes every context it exports through that context's facade,
/// never its internals). notify_changed is injected from bootstrap so the
/// collection write publishes to the same collection-changed subscriber
/// ImportCollection uses (ADR 0011), rather than this adapter wiring a
/// second one — neither target-set replacement nor the plan replace have a
/// subscriber to notify.
pub fn new(
  notify_changed: fn(Nil) -> Result(Nil, String),
) -> ports.ImportDataPorts {
  ports.ImportDataPorts(
    check_rule: check_rule_adapter,
    check_sort_keys: inventory_planning_api.check_sort_keys,
    replace_target_sets: insights_api.replace_target_sets,
    replace_plan: replace_plan_adapter,
    replace_collection: replace_collection_adapter(notify_changed),
  )
}

fn check_rule_adapter(rule: Rule) -> Result(Nil, String) {
  inventory_planning_api.check_rule(to_rule_spec(rule))
}

fn replace_plan_adapter(
  rules: option.Option(List(Rule)),
  bulk: option.Option(BulkSpec),
  placed: option.Option(List(PlacedEntry)),
) -> Result(Nil, String) {
  inventory_planning_api.replace_plan(
    option.map(rules, list.map(_, to_rule_spec)),
    option.map(bulk, to_bulk_spec_spec),
    option.map(placed, list.map(_, to_placed_copy)),
  )
}

fn to_rule_spec(rule: Rule) -> inventory_planning_api.RuleSpec {
  inventory_planning_api.RuleSpec(
    location: rule.location,
    expression: rule.expression,
    selector: rule.selector,
    sort_keys: rule.sort_keys,
  )
}

fn to_bulk_spec_spec(spec: BulkSpec) -> inventory_planning_api.BulkSpecSpec {
  inventory_planning_api.BulkSpecSpec(
    location: spec.location,
    sort_keys: spec.sort_keys,
  )
}

fn to_placed_copy(entry: PlacedEntry) -> inventory_planning_api.PlacedCopy {
  inventory_planning_api.PlacedCopy(
    key: entry.key,
    location: entry.location,
    quantity: entry.quantity,
  )
}

fn replace_collection_adapter(
  notify_changed: fn(Nil) -> Result(Nil, String),
) -> ports.ReplaceCollectionPort {
  fn(entries) {
    collection_api.replace_copies(
      list.map(entries, to_owned_copy),
      notify_changed,
    )
  }
}

fn to_owned_copy(entry: CollectionEntry) -> collection_api.OwnedCopy {
  collection_api.OwnedCopy(key: entry.key, quantity: entry.quantity)
}
