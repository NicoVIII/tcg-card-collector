import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import inventory_planning/application/commands/restore_plan/ports
import inventory_planning/domain/card_predicate
import inventory_planning/domain/copy_selector
import inventory_planning/domain/location_ref
import inventory_planning/domain/managed_location.{type ManagedLocation}
import inventory_planning/domain/placement
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

/// `location_kind` is "cascade" or "managed". For a cascade location,
/// `location` is its name; for a managed one it is the managed location's
/// *name* too, not its id — a restore assigns fresh ids, so the name is the
/// only identity the caller can hold. It resolves against the managed
/// locations being restored, or the existing ones when none are.
pub type RawPlaced {
  RawPlaced(
    set_code: String,
    collector_number: String,
    finish: String,
    language: String,
    location_kind: String,
    location: String,
    quantity: Int,
  )
}

pub type RawMember {
  RawMember(
    set_code: String,
    collector_number: String,
    finish: String,
    language: String,
    quantity: Int,
  )
}

/// No id, same reasoning as RawRule: this command assigns
/// `imported-managed-<position>` itself.
pub type RawManagedLocation {
  RawManagedLocation(name: String, kind: String, members: List(RawMember))
}

pub type RestorePlanCommand {
  RestorePlanCommand(
    rules: Option(List(RawRule)),
    bulk: Option(RawBulkSpec),
    managed: Option(List(RawManagedLocation)),
    placed: Option(List(RawPlaced)),
  )
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
  use managed <- result.try(validate_managed(command.managed))
  use managed_ids <- result.try(managed_ids_by_name(managed, ports))
  use placed <- result.try(validate_placed(command.placed, managed_ids))

  ports.replace_plan(rules, bulk, managed, placed)
  |> result.map_error(ports.PersistenceFailed)
}

fn validate_managed(
  raw: Option(List(RawManagedLocation)),
) -> Result(Option(List(ManagedLocation)), ports.RestorePlanError) {
  case raw {
    None -> Ok(None)
    Some(rows) -> {
      use locations <- result.try(
        rows
        |> list.index_map(to_managed_location)
        |> result.all
        |> result.replace_error(ports.InvalidManagedLocations),
      )
      let names = list.map(locations, fn(location) { location.name })
      case list.length(list.unique(names)) == list.length(names) {
        True -> Ok(Some(locations))
        False -> Error(ports.InvalidManagedLocations)
      }
    }
  }
}

fn to_managed_location(
  row: RawManagedLocation,
  position: Int,
) -> Result(ManagedLocation, Nil) {
  use name <- result.try(managed_location.parse_name(row.name))
  use kind <- result.try(managed_location.kind_from_string(row.kind))
  use deltas <- result.try(list.try_map(row.members, to_member_delta))
  Ok(managed_location.ManagedLocation(
    id: "imported-managed-" <> int.to_string(position),
    name:,
    kind:,
    members: managed_location.merge_deltas(deltas)
      |> list.map(fn(delta) { #(delta.key, delta.quantity) })
      |> dict.from_list,
  ))
}

fn to_member_delta(
  member: RawMember,
) -> Result(managed_location.MemberDelta, Nil) {
  managed_location.delta_from_input(
    set_code: member.set_code,
    collector_number: member.collector_number,
    finish: member.finish,
    language: member.language,
    quantity: member.quantity,
  )
}

// A managed placed entry names its location; resolve against the set being
// restored when there is one (it replaces the old one wholesale), else the
// existing locations.
fn managed_ids_by_name(
  restored: Option(List(ManagedLocation)),
  ports: ports.RestorePlanPorts,
) -> Result(Dict(String, String), ports.RestorePlanError) {
  use locations <- result.map(case restored {
    Some(locations) -> Ok(locations)
    None ->
      ports.list_managed_locations()
      |> result.map_error(ports.PersistenceFailed)
  })
  locations
  |> list.map(fn(location) { #(location.name, location.id) })
  |> dict.from_list
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

fn validate_placed(
  raw: Option(List(RawPlaced)),
  managed_ids: Dict(String, String),
) -> Result(Option(List(ports.PlacedWriteModel)), ports.RestorePlanError) {
  case raw {
    None -> Ok(None)
    Some(rows) ->
      rows
      |> list.try_map(to_placement(_, managed_ids))
      |> result.replace_error(ports.InvalidPlaced)
      |> result.map(fn(placements) {
        Some(list.map(placement.merge(placements), to_placed_write_model))
      })
  }
}

fn to_placement(
  row: RawPlaced,
  managed_ids: Dict(String, String),
) -> Result(placement.Placement, placement.PlacementError) {
  use location <- result.try(case row.location_kind {
    "managed" ->
      dict.get(managed_ids, row.location)
      |> result.replace_error(placement.InvalidLocation)
    _ -> Ok(row.location)
  })
  placement.new(
    set_code: row.set_code,
    collector_number: row.collector_number,
    finish: row.finish,
    language: row.language,
    location_kind: row.location_kind,
    location:,
    quantity: row.quantity,
  )
}

fn to_placed_write_model(p: placement.Placement) -> ports.PlacedWriteModel {
  ports.PlacedWriteModel(
    key: placement.key(p),
    location: placement.location(p),
    quantity: placement.quantity(p),
  )
}
