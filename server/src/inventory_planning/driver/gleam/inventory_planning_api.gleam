import gleam/dict
import gleam/list
import gleam/option.{type Option}
import gleam/result
import inventory_planning/application/commands/restore_plan/handler as restore_plan_handler
import inventory_planning/application/commands/restore_plan/ports as restore_plan_ports
import inventory_planning/application/queries/get_bulk_spec/handler as get_bulk_spec_handler
import inventory_planning/application/queries/list_managed_locations/handler as list_managed_locations_handler
import inventory_planning/application/queries/list_rules/handler as list_rules_handler
import inventory_planning/application/queries/placed_ledger/handler as placed_ledger_handler
import inventory_planning/domain/card_predicate
import inventory_planning/domain/copy_selector
import inventory_planning/domain/location_ref
import inventory_planning/domain/managed_location
import inventory_planning/domain/sort_spec

// nolint: depends_only_on -- glinter_arch doesn't yet allow Driver->own-BC-Infrastructure, though AGENTS.md documents it; fixing needs a gleam-libs change
import inventory_planning/infrastructure/adapters/commands/restore_plan/adapter as restore_plan_adapter

// nolint: depends_only_on -- glinter_arch doesn't yet allow Driver->own-BC-Infrastructure, though AGENTS.md documents it; fixing needs a gleam-libs change
import inventory_planning/infrastructure/adapters/queries/get_bulk_spec/adapter as get_bulk_spec_adapter

// nolint: depends_only_on -- glinter_arch doesn't yet allow Driver->own-BC-Infrastructure, though AGENTS.md documents it; fixing needs a gleam-libs change
import inventory_planning/infrastructure/adapters/queries/list_managed_locations/adapter as list_managed_locations_adapter

// nolint: depends_only_on -- glinter_arch doesn't yet allow Driver->own-BC-Infrastructure, though AGENTS.md documents it; fixing needs a gleam-libs change
import inventory_planning/infrastructure/adapters/queries/list_rules/adapter as list_rules_adapter

// nolint: depends_only_on -- glinter_arch doesn't yet allow Driver->own-BC-Infrastructure, though AGENTS.md documents it; fixing needs a gleam-libs change
import inventory_planning/infrastructure/adapters/queries/placed_ledger/adapter as placed_ledger_adapter
import shared/domain/copy_key.{type CopyKey}

// A rule's four hand-authored fields, in the DSL text form the location
// cascade already stores canonically — the id and cascade position aren't
// carried here: id is inventory_planning's own concern, and position is the
// list's own order (ADR 0019, same reasoning as ExportDocument's collection
// order).
pub type RuleSpec {
  RuleSpec(
    location: String,
    expression: String,
    selector: String,
    sort_keys: String,
  )
}

pub type BulkSpecSpec {
  BulkSpecSpec(location: String, sort_keys: String)
}

/// Where a placed copy sits, by name in both namespaces (ADR 0022): a
/// managed location's id is this context's own concern and doesn't survive
/// a restore, so Portability only ever sees its name.
pub type PlacedAt {
  AtCascadeLocation(name: String)
  AtManagedLocation(name: String)
}

pub type PlacedCopy {
  PlacedCopy(key: CopyKey, location: PlacedAt, quantity: Int)
}

/// A managed location's hand-made state: its name (unique among managed
/// locations), its kind's text form, and its whole membership.
pub type ManagedLocationSpec {
  ManagedLocationSpec(
    name: String,
    kind: String,
    members: List(#(CopyKey, Int)),
  )
}

pub fn list_rules() -> Result(List(RuleSpec), String) {
  use rows <- result.map(list_rules_handler.execute(
    list_rules_handler.ListInventoryRulesQuery,
    list_rules_adapter.new(),
  ))
  list.map(rows, fn(row) {
    RuleSpec(
      location: row.location_name,
      expression: row.expression,
      selector: row.selector,
      sort_keys: row.sort_keys,
    )
  })
}

pub fn get_bulk_spec() -> Result(BulkSpecSpec, String) {
  use spec <- result.map(get_bulk_spec_handler.execute(
    get_bulk_spec_handler.GetBulkSpecQuery,
    get_bulk_spec_adapter.new(),
  ))
  BulkSpecSpec(location: spec.location_name, sort_keys: spec.sort_keys)
}

fn load_managed_locations() -> Result(
  List(managed_location.ManagedLocation),
  String,
) {
  list_managed_locations_handler.execute(
    list_managed_locations_handler.ListManagedLocationsQuery,
    list_managed_locations_adapter.new(),
  )
}

pub fn list_managed_locations() -> Result(List(ManagedLocationSpec), String) {
  use locations <- result.map(load_managed_locations())
  list.map(locations, fn(location) {
    ManagedLocationSpec(
      name: location.name,
      kind: managed_location.kind_to_string(location.kind),
      members: location.members
        |> dict.to_list
        |> managed_location.sorted_by_key,
    )
  })
}

pub fn list_placed() -> Result(List(PlacedCopy), String) {
  use rows <- result.try(placed_ledger_handler.execute(
    placed_ledger_handler.GetPlacedLedgerQuery,
    placed_ledger_adapter.new(),
  ))
  use locations <- result.map(load_managed_locations())
  let names =
    locations
    |> list.map(fn(location) { #(location.id, location.name) })
    |> dict.from_list
  list.filter_map(rows, fn(row) {
    // The ledger only ever holds rows written through placement.new, which
    // already validated this same identity, and deleting a managed location
    // removes its rows — both failures are unreachable in practice.
    use key <- result.try(
      copy_key.new(
        set_code: row.set_code,
        collector_number: row.collector_number,
        finish: row.finish,
        language: row.language,
      )
      |> result.replace_error(Nil),
    )
    use location <- result.map(case row.location {
      location_ref.Cascade(name) -> Ok(AtCascadeLocation(name))
      location_ref.Managed(id) ->
        dict.get(names, id) |> result.map(AtManagedLocation)
    })
    PlacedCopy(key:, location:, quantity: row.quantity)
  })
}

/// Validates a rule's DSL fields without persisting — Portability's import
/// preview uses this to report a bad rule before anything is written
/// (ADR 0019). The location field isn't checked: it doubles as a fan-out
/// template and `location_target.parse` accepts any string.
pub fn check_rule(rule: RuleSpec) -> Result(Nil, String) {
  use _ <- result.try(
    copy_selector.parse(rule.selector)
    |> result.replace_error("unrecognized copies selector"),
  )
  use _ <- result.try(
    card_predicate.parse(rule.expression)
    |> result.replace_error("invalid match expression"),
  )
  check_sort_keys(rule.sort_keys)
}

pub fn check_sort_keys(raw: String) -> Result(Nil, String) {
  sort_spec.parse_sort_keys(raw)
  |> result.replace_error("invalid sort keys")
  |> result.map(fn(_) { Nil })
}

/// Validates a managed location's kind without persisting — the import
/// preview's counterpart of check_rule.
pub fn check_managed_location_kind(raw: String) -> Result(Nil, String) {
  managed_location.kind_from_string(raw)
  |> result.replace_error("unknown kind \"" <> raw <> "\"")
  |> result.map(fn(_) { Nil })
}

/// Replaces whichever of rules/bulk/managed/placed are given, atomically together,
/// reusing RestorePlan's own validation and persistence — the caller
/// (Portability) already holds entries it validated at the document level
/// via check_rule/check_sort_keys (ADR 0019), so this is defense-in-depth.
pub fn replace_plan(
  rules: Option(List(RuleSpec)),
  bulk: Option(BulkSpecSpec),
  managed: Option(List(ManagedLocationSpec)),
  placed: Option(List(PlacedCopy)),
) -> Result(Nil, String) {
  case
    restore_plan_handler.execute(
      restore_plan_handler.RestorePlanCommand(
        rules: option.map(rules, list.map(_, to_raw_rule)),
        bulk: option.map(bulk, to_raw_bulk_spec),
        managed: option.map(managed, list.map(_, to_raw_managed_location)),
        placed: option.map(placed, list.map(_, to_raw_placed)),
      ),
      restore_plan_adapter.new(),
    )
  {
    Ok(Nil) -> Ok(Nil)
    Error(restore_plan_ports.InvalidRules) -> Error("invalid rules")
    Error(restore_plan_ports.InvalidBulkSpec) -> Error("invalid bulk spec")
    Error(restore_plan_ports.InvalidManagedLocations) ->
      Error("invalid managed locations")
    Error(restore_plan_ports.InvalidPlaced) -> Error("invalid placed copies")
    Error(restore_plan_ports.PersistenceFailed(reason)) -> Error(reason)
  }
}

fn to_raw_rule(rule: RuleSpec) -> restore_plan_handler.RawRule {
  restore_plan_handler.RawRule(
    location_name: rule.location,
    expression: rule.expression,
    selector: rule.selector,
    sort_keys: rule.sort_keys,
  )
}

fn to_raw_bulk_spec(spec: BulkSpecSpec) -> restore_plan_handler.RawBulkSpec {
  restore_plan_handler.RawBulkSpec(
    location_name: spec.location,
    sort_keys: spec.sort_keys,
  )
}

fn to_raw_managed_location(
  spec: ManagedLocationSpec,
) -> restore_plan_handler.RawManagedLocation {
  restore_plan_handler.RawManagedLocation(
    name: spec.name,
    kind: spec.kind,
    members: list.map(spec.members, fn(member) {
      let #(key, quantity) = member
      restore_plan_handler.RawMember(
        set_code: copy_key.set_code_string(key),
        collector_number: copy_key.collector_number_string(key),
        finish: copy_key.finish_string(key),
        language: copy_key.language_string(key),
        quantity:,
      )
    }),
  )
}

fn to_raw_placed(copy: PlacedCopy) -> restore_plan_handler.RawPlaced {
  let #(location_kind, location) = case copy.location {
    AtCascadeLocation(name) -> #("cascade", name)
    AtManagedLocation(name) -> #("managed", name)
  }
  restore_plan_handler.RawPlaced(
    set_code: copy_key.set_code_string(copy.key),
    collector_number: copy_key.collector_number_string(copy.key),
    finish: copy_key.finish_string(copy.key),
    language: copy_key.language_string(copy.key),
    location_kind:,
    location:,
    quantity: copy.quantity,
  )
}
