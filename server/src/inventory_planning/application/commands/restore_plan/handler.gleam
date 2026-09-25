import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import inventory_planning/application/commands/restore_plan/ports
import inventory_planning/domain/card_predicate
import inventory_planning/domain/copy_selector
import inventory_planning/domain/placement
import inventory_planning/domain/sort_spec
import shared/application/command_result
import shared/domain/copy_key

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

pub type RawPlaced {
  RawPlaced(
    set_code: String,
    collector_number: String,
    finish: String,
    language: String,
    location_name: String,
    quantity: Int,
  )
}

pub type RestorePlanCommand {
  RestorePlanCommand(
    rules: Option(List(RawRule)),
    bulk: Option(RawBulkSpec),
    placed: Option(List(RawPlaced)),
  )
}

/// Replaces whichever sections are present with a full snapshot — the same
/// all-or-nothing-per-section posture Portability's other restore paths use
/// (ImportCollection, ReplaceTargetSets). The caller (Portability) already
/// holds entries it pre-filtered at the document level (ADR 0019), so this
/// re-validation is defense-in-depth: a genuine failure here means
/// Portability's own check_rule/check_sort_keys ports disagreed with this
/// command's parsers, which should not happen in practice.
pub fn execute(
  command: RestorePlanCommand,
  ports: ports.RestorePlanPorts,
) -> command_result.CommandResult(ports.RestorePlanError) {
  use rules <- result.try(validate_rules(command.rules))
  use bulk <- result.try(validate_bulk(command.bulk))
  use placed <- result.try(validate_placed(command.placed))

  ports.replace_plan(rules, bulk, placed)
  |> result.map_error(ports.PersistenceFailed)
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
    location_name: row.location_name,
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
      use sort_keys <- result.try(
        sort_spec.parse_sort_keys(spec.sort_keys)
        |> result.replace_error(ports.InvalidBulkSpec),
      )
      Ok(
        Some(ports.BulkSpecWriteModel(
          location_name: spec.location_name,
          sort_keys: sort_spec.sort_keys_to_string(sort_keys),
        )),
      )
    }
  }
}

fn validate_placed(
  raw: Option(List(RawPlaced)),
) -> Result(Option(List(ports.PlacedWriteModel)), ports.RestorePlanError) {
  case raw {
    None -> Ok(None)
    Some(rows) ->
      rows
      |> list.try_map(to_placement)
      |> result.replace_error(ports.InvalidPlaced)
      |> result.try(fn(placements) {
        placements
        |> placement.merge
        |> list.try_map(to_placed_write_model)
        |> result.replace_error(ports.InvalidPlaced)
        |> result.map(Some)
      })
  }
}

fn to_placement(
  row: RawPlaced,
) -> Result(placement.Placement, placement.PlacementError) {
  placement.new(
    set_code: row.set_code,
    collector_number: row.collector_number,
    finish: row.finish,
    language: row.language,
    location: row.location_name,
    quantity: row.quantity,
  )
}

// placement.Placement is opaque and exposes no key accessor, only the
// individual identity strings it validated — this rebuilds the CopyKey from
// those, which always succeeds since they already round-tripped through
// copy_key once inside `placement.new`.
fn to_placed_write_model(
  p: placement.Placement,
) -> Result(ports.PlacedWriteModel, Nil) {
  use key <- result.try(
    copy_key.new(
      set_code: placement.set_code_string(p),
      collector_number: placement.collector_number_string(p),
      finish: placement.finish_string(p),
      language: placement.language_string(p),
    )
    |> result.replace_error(Nil),
  )
  Ok(ports.PlacedWriteModel(
    key:,
    location: placement.location(p),
    quantity: placement.quantity(p),
  ))
}
