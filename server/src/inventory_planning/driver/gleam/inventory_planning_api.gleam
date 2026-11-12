import gleam/dict
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/time/timestamp.{type Timestamp}
import inventory_planning/application/commands/restore_plan/handler as restore_plan_handler
import inventory_planning/application/commands/restore_plan/ports as restore_plan_ports
import inventory_planning/application/queries/get_bulk_spec/handler as get_bulk_spec_handler
import inventory_planning/application/queries/list_managed_locations/handler as list_managed_locations_handler
import inventory_planning/application/queries/list_rules/handler as list_rules_handler
import inventory_planning/application/queries/placed_ledger/handler as placed_ledger_handler
import inventory_planning/application/queries/predict_restore_prune/handler as predict_restore_prune_handler
import inventory_planning/application/queries/predict_restore_prune/ports as predict_restore_prune_ports
import inventory_planning/domain/card_predicate
import inventory_planning/domain/copy_selector
import inventory_planning/domain/location_audit.{type AuditRecord}
import inventory_planning/domain/location_ref
import inventory_planning/domain/managed_location
import inventory_planning/domain/plan_restore
import inventory_planning/domain/sort_spec

// nolint: depends_only_on -- glinter_arch doesn't yet allow Driver->own-BC-Infrastructure, though AGENTS.md documents it; fixing needs a gleam-libs change
import inventory_planning/infrastructure/adapters/commands/restore_plan/adapter as restore_plan_adapter

// nolint: depends_only_on -- glinter_arch doesn't yet allow Driver->own-BC-Infrastructure, though AGENTS.md documents it; fixing needs a gleam-libs change
import inventory_planning/infrastructure/adapters/queries/get_bulk_spec/adapter as get_bulk_spec_adapter

// nolint: depends_only_on -- glinter_arch doesn't yet allow Driver->own-BC-Infrastructure, though AGENTS.md documents it; fixing needs a gleam-libs change
import inventory_planning/infrastructure/adapters/queries/list_location_audits/adapter as list_location_audits_adapter

// nolint: depends_only_on -- glinter_arch doesn't yet allow Driver->own-BC-Infrastructure, though AGENTS.md documents it; fixing needs a gleam-libs change
import inventory_planning/infrastructure/adapters/queries/list_managed_locations/adapter as list_managed_locations_adapter

// nolint: depends_only_on -- glinter_arch doesn't yet allow Driver->own-BC-Infrastructure, though AGENTS.md documents it; fixing needs a gleam-libs change
import inventory_planning/infrastructure/adapters/queries/list_rules/adapter as list_rules_adapter

// nolint: depends_only_on -- glinter_arch doesn't yet allow Driver->own-BC-Infrastructure, though AGENTS.md documents it; fixing needs a gleam-libs change
import inventory_planning/infrastructure/adapters/queries/placed_ledger/adapter as placed_ledger_adapter

// nolint: depends_only_on -- glinter_arch doesn't yet allow Driver->own-BC-Infrastructure, though AGENTS.md documents it; fixing needs a gleam-libs change
import inventory_planning/infrastructure/adapters/queries/predict_restore_prune/adapter as predict_restore_prune_adapter
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

/// One completed location audit, its location named as in `PlacedCopy`.
pub type AuditedAt {
  AuditedAt(location: PlacedAt, completed_at: Timestamp)
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

fn to_audited_at(
  record: AuditRecord,
  names: dict.Dict(String, String),
) -> Result(AuditedAt, Nil) {
  use location <- result.map(case record.location {
    location_ref.Cascade(name) -> Ok(AtCascadeLocation(name))
    location_ref.Managed(id) ->
      dict.get(names, id) |> result.map(AtManagedLocation)
  })
  AuditedAt(location:, completed_at: record.completed_at)
}

/// Every completed audit, not only each location's latest — the whole
/// history is hand-made state a backup carries (#183). Deleting or replacing
/// a managed location removes its audits, so an unknown id is unreachable.
pub fn list_audit_history() -> Result(List(AuditedAt), String) {
  use records <- result.try(list_location_audits_adapter.new()())
  use locations <- result.map(load_managed_locations())
  let names =
    locations
    |> list.map(fn(location) { #(location.id, location.name) })
    |> dict.from_list
  list.filter_map(records, to_audited_at(_, names))
}

fn check_location_name(raw: String) -> Result(Nil, String) {
  location_ref.parse_cascade_name(raw)
  |> result.replace_error("location name is blank")
  |> result.map(fn(_) { Nil })
}

fn check_sort_keys(raw: String) -> Result(Nil, String) {
  sort_spec.parse_sort_keys(raw)
  |> result.replace_error("invalid sort keys")
  |> result.map(fn(_) { Nil })
}

/// Validates a rule without persisting — Portability's import preview uses
/// this to report a bad rule before anything is written (ADR 0019).
pub fn check_rule(rule: RuleSpec) -> Result(Nil, String) {
  use _ <- result.try(check_location_name(rule.location))
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

/// The bulk spec's counterpart of check_rule.
pub fn check_bulk_spec(spec: BulkSpecSpec) -> Result(Nil, String) {
  use _ <- result.try(check_location_name(spec.location))
  check_sort_keys(spec.sort_keys)
}

/// Validates a managed location's kind without persisting — the import
/// preview's counterpart of check_rule.
pub fn check_managed_location_kind(raw: String) -> Result(Nil, String) {
  managed_location.kind_from_string(raw)
  |> result.replace_error("unknown kind \"" <> raw <> "\"")
  |> result.map(fn(_) { Nil })
}

fn restore_plan_error_message(
  error: restore_plan_ports.RestorePlanError,
) -> String {
  case error {
    restore_plan_ports.InvalidRules -> "invalid rules"
    restore_plan_ports.InvalidBulkSpec -> "invalid bulk spec"
    restore_plan_ports.InvalidManagedLocations -> "invalid managed locations"
    restore_plan_ports.InvalidPlaced -> "invalid placed copies"
    restore_plan_ports.InvalidAudits -> "invalid audit history"
    restore_plan_ports.PersistenceFailed(reason) -> reason
  }
}

/// Replaces whichever of rules/bulk/managed/placed/audits are given,
/// atomically together, reusing RestorePlan's own validation and persistence
/// — the caller (Portability) already holds entries it validated at the
/// document level via check_rule/check_bulk_spec (ADR 0019), so this is
/// defense-in-depth. Without `audits`, replacing the ledger empties the audit
/// history (`restore_clears_audit_history`).
pub fn replace_plan(
  rules: Option(List(RuleSpec)),
  bulk: Option(BulkSpecSpec),
  managed: Option(List(ManagedLocationSpec)),
  placed: Option(List(PlacedCopy)),
  audits: Option(List(AuditedAt)),
) -> Result(Nil, String) {
  case
    restore_plan_handler.execute(
      restore_plan_handler.RestorePlanCommand(
        rules: option.map(rules, list.map(_, to_raw_rule)),
        bulk: option.map(bulk, to_raw_bulk_spec),
        managed: option.map(managed, list.map(_, to_raw_managed_location)),
        placed: option.map(placed, list.map(_, to_raw_placed)),
        audits: option.map(audits, list.map(_, to_raw_audit)),
      ),
      restore_plan_adapter.new(),
    )
  {
    Ok(Nil) -> Ok(Nil)
    Error(error) -> Error(restore_plan_error_message(error))
  }
}

/// Whether `replace_plan` with these sections present empties the audit
/// history, so the restore preview can say so before anything is written.
pub fn restore_clears_audit_history(
  restores_audits restores_audits: Bool,
  replaces_ledger replaces_ledger: Bool,
) -> Bool {
  plan_restore.clears_audit_history(restores_audits:, replaces_ledger:)
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
) -> plan_restore.RawManagedLocation {
  plan_restore.RawManagedLocation(
    name: spec.name,
    kind: spec.kind,
    members: list.map(spec.members, fn(member) {
      let #(key, quantity) = member
      plan_restore.RawMember(
        set_code: copy_key.set_code_string(key),
        collector_number: copy_key.collector_number_string(key),
        finish: copy_key.finish_string(key),
        language: copy_key.language_string(key),
        quantity:,
      )
    }),
  )
}

fn placed_at_parts(location: PlacedAt) -> #(String, String) {
  case location {
    AtCascadeLocation(name) -> #("cascade", name)
    AtManagedLocation(name) -> #("managed", name)
  }
}

fn to_raw_placed(copy: PlacedCopy) -> plan_restore.RawPlaced {
  let #(location_kind, location) = placed_at_parts(copy.location)
  plan_restore.RawPlaced(
    set_code: copy_key.set_code_string(copy.key),
    collector_number: copy_key.collector_number_string(copy.key),
    finish: copy_key.finish_string(copy.key),
    language: copy_key.language_string(copy.key),
    location_kind:,
    location:,
    quantity: copy.quantity,
  )
}

fn to_raw_audit(audit: AuditedAt) -> plan_restore.RawAudit {
  let #(location_kind, location) = placed_at_parts(audit.location)
  plan_restore.RawAudit(
    location_kind:,
    location:,
    completed_at: audit.completed_at,
  )
}

fn to_pruned_copy(
  pruned: predict_restore_prune_handler.PrunedRow,
) -> PlacedCopy {
  let predict_restore_prune_handler.PrunedRow(row:, location_name:) = pruned
  let location = case row.location {
    location_ref.Cascade(_) -> AtCascadeLocation(location_name)
    location_ref.Managed(_) -> AtManagedLocation(location_name)
  }
  PlacedCopy(key: row.key, location:, quantity: row.quantity)
}

/// The placed copies ReconcilePlacedLedger will prune right after a restore
/// writing `owned` as the collection plus the given managed and placed
/// sections (`None` = section absent, left untouched). Each copy's quantity
/// is the amount pruned, not what remains.
pub fn predict_restore_prune(
  owned: List(#(CopyKey, Int)),
  managed: Option(List(ManagedLocationSpec)),
  placed: Option(List(PlacedCopy)),
) -> Result(List(PlacedCopy), String) {
  predict_restore_prune_handler.execute(
    predict_restore_prune_handler.PredictRestorePruneQuery(
      owned: dict.from_list(owned),
      managed: option.map(managed, list.map(_, to_raw_managed_location)),
      placed: option.map(placed, list.map(_, to_raw_placed)),
    ),
    predict_restore_prune_adapter.new(),
  )
  |> result.map(list.map(_, to_pruned_copy))
  |> result.map_error(fn(error) {
    case error {
      predict_restore_prune_ports.InvalidPlan(
        plan_restore.InvalidManagedLocations,
      ) ->
        restore_plan_error_message(restore_plan_ports.InvalidManagedLocations)
      predict_restore_prune_ports.InvalidPlan(plan_restore.InvalidPlaced) ->
        restore_plan_error_message(restore_plan_ports.InvalidPlaced)
      predict_restore_prune_ports.InvalidPlan(plan_restore.InvalidAudits) ->
        restore_plan_error_message(restore_plan_ports.InvalidAudits)
      predict_restore_prune_ports.UnknownManagedLocation(id) ->
        "placed ledger names unknown managed location " <> id
      predict_restore_prune_ports.PersistenceFailed(reason) -> reason
    }
  })
}
