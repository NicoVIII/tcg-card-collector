import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import inventory_planning/application/commands/restore_plan/ports
import inventory_planning/domain/card_predicate
import inventory_planning/domain/copy_selector
import inventory_planning/domain/location_ref
import inventory_planning/domain/placed_ledger_reconciliation.{type PlacedRow}
import inventory_planning/domain/plan_restore
import inventory_planning/domain/sort_spec
import shared/application/command_result

/// A rule as it arrives on the wire, before validation — no id: the cascade
/// position (its array order) is the only identity a restore carries, so
/// this command assigns a deterministic `imported-<position>` id itself
/// rather than trusting one from the caller.
pub type RawRule {
  RawRule(
    location_name: String,
    expression: String,
    selector: String,
    sort_keys: String,
  )
}

pub type RawBulkSpec {
  RawBulkSpec(location_name: String, sort_keys: String)
}

pub type RestorePlanCommand {
  RestorePlanCommand(
    rules: Option(List(RawRule)),
    bulk: Option(RawBulkSpec),
    managed: Option(List(plan_restore.RawManagedLocation)),
    placed: Option(List(plan_restore.RawPlaced)),
  )
}

fn to_restore_plan_error(
  error: plan_restore.PlanRestoreError,
) -> ports.RestorePlanError {
  case error {
    plan_restore.InvalidManagedLocations -> ports.InvalidManagedLocations
    plan_restore.InvalidPlaced -> ports.InvalidPlaced
  }
}

fn to_placed_write_model(row: PlacedRow) -> ports.PlacedWriteModel {
  ports.PlacedWriteModel(
    key: row.key,
    location: row.location,
    quantity: row.quantity,
  )
}

fn validate_rules(
  raw: Option(List(RawRule)),
) -> Result(Option(List(ports.RuleWriteModel)), ports.RestorePlanError) {
  case raw {
    None -> Ok(None)
    Some(rows) ->
      rows
      |> list.index_map(to_rule_write_model)
      |> result.all
      |> result.replace_error(ports.InvalidRules)
      |> result.map(Some)
  }
}

fn to_rule_write_model(
  row: RawRule,
  position: Int,
) -> Result(ports.RuleWriteModel, Nil) {
  use location_name <- result.try(location_ref.parse_cascade_name(
    row.location_name,
  ))
  use selector <- result.try(
    copy_selector.parse(row.selector) |> result.replace_error(Nil),
  )
  use predicate <- result.try(
    card_predicate.parse(row.expression) |> result.replace_error(Nil),
  )
  use sort_keys <- result.try(
    sort_spec.parse_sort_keys(row.sort_keys) |> result.replace_error(Nil),
  )
  Ok(ports.RuleWriteModel(
    id: "imported-" <> int.to_string(position),
    location_name:,
    expression: card_predicate.to_string(predicate),
    position:,
    selector: copy_selector.to_string(selector),
    sort_keys: sort_spec.sort_keys_to_string(sort_keys),
  ))
}

fn validate_bulk(
  raw: Option(RawBulkSpec),
) -> Result(Option(ports.BulkSpecWriteModel), ports.RestorePlanError) {
  case raw {
    None -> Ok(None)
    Some(spec) -> {
      use location_name <- result.try(
        location_ref.parse_cascade_name(spec.location_name)
        |> result.replace_error(ports.InvalidBulkSpec),
      )
      use sort_keys <- result.try(
        sort_spec.parse_sort_keys(spec.sort_keys)
        |> result.replace_error(ports.InvalidBulkSpec),
      )
      Ok(
        Some(ports.BulkSpecWriteModel(
          location_name:,
          sort_keys: sort_spec.sort_keys_to_string(sort_keys),
        )),
      )
    }
  }
}

/// Replaces whichever sections are present with a full snapshot — the same
/// all-or-nothing-per-section posture Portability's other restore paths use
/// (ImportCollection, ReplaceTargetSets). The caller (Portability) already
/// holds entries it pre-filtered at the document level (ADR 0019), so this
/// re-validation is defense-in-depth: a genuine failure here means
/// Portability's own check_rule/check_bulk_spec ports disagreed with this
/// command's parsers, which should not happen in practice.
pub fn execute(
  command: RestorePlanCommand,
  ports: ports.RestorePlanPorts,
) -> command_result.CommandResult(ports.RestorePlanError) {
  use rules <- result.try(validate_rules(command.rules))
  use bulk <- result.try(validate_bulk(command.bulk))
  use existing_managed <- result.try(
    ports.list_managed_locations()
    |> result.map_error(ports.PersistenceFailed),
  )
  use #(managed, placed) <- result.try(
    plan_restore.restored_ledger(
      command.managed,
      command.placed,
      existing_managed,
    )
    |> result.map_error(to_restore_plan_error),
  )
  ports.replace_plan(
    rules,
    bulk,
    managed,
    option.map(placed, list.map(_, to_placed_write_model)),
  )
  |> result.map_error(ports.PersistenceFailed)
}
