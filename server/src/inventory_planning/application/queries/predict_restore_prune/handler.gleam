import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import inventory_planning/application/queries/predict_restore_prune/ports
import inventory_planning/domain/location_ref
import inventory_planning/domain/managed_location.{type ManagedLocation}
import inventory_planning/domain/placed_ledger_reconciliation.{type PlacedRow}
import inventory_planning/domain/plan_restore
import shared/domain/copy_key.{type CopyKey}

/// The sections of a restore that decide the ledger it leaves behind, as
/// RestorePlan receives them. `owned` is the collection the restore writes.
pub type PredictRestorePruneQuery {
  PredictRestorePruneQuery(
    owned: Dict(CopyKey, Int),
    managed: Option(List(plan_restore.RawManagedLocation)),
    placed: Option(List(plan_restore.RawPlaced)),
  )
}

/// A row ReconcilePlacedLedger will prune, with its location's name: a
/// restored managed location's id doesn't exist yet, so the caller can't
/// resolve it.
pub type PrunedRow {
  PrunedRow(row: PlacedRow, location_name: String)
}

// Reads the current ledger only when the restore keeps it.
fn ledger_after(
  restored: Option(List(PlacedRow)),
  replaces_managed: Bool,
  ports: ports.PredictRestorePrunePorts,
) -> Result(List(PlacedRow), ports.PredictRestorePruneError) {
  use current <- result.map(case restored {
    Some(_) -> Ok([])
    None -> ports.list_placed() |> result.map_error(ports.PersistenceFailed)
  })
  placed_ledger_reconciliation.ledger_after_restore(
    current,
    replaces_managed,
    restored,
  )
}

fn managed_names(locations: List(ManagedLocation)) -> Dict(String, String) {
  locations
  |> list.map(fn(location) { #(location.id, location.name) })
  |> dict.from_list
}

fn name_location(
  row: PlacedRow,
  managed_names: Dict(String, String),
) -> Result(PrunedRow, ports.PredictRestorePruneError) {
  case row.location {
    location_ref.Cascade(name) -> Ok(PrunedRow(row:, location_name: name))
    location_ref.Managed(id) ->
      dict.get(managed_names, id)
      |> result.replace_error(ports.UnknownManagedLocation(id))
      |> result.map(fn(name) { PrunedRow(row:, location_name: name) })
  }
}

/// What ReconcilePlacedLedger prunes right after a restore with these
/// sections (ADR 0011): the same prune, run on the ledger the restore leaves
/// behind, so it names exactly the rows the reconcile removes.
pub fn execute(
  query: PredictRestorePruneQuery,
  ports: ports.PredictRestorePrunePorts,
) -> Result(List(PrunedRow), ports.PredictRestorePruneError) {
  use existing_managed <- result.try(
    ports.list_managed_locations()
    |> result.map_error(ports.PersistenceFailed),
  )
  use #(restored_managed, restored_placed) <- result.try(
    plan_restore.restored_ledger(query.managed, query.placed, existing_managed)
    |> result.map_error(ports.InvalidPlan),
  )
  use ledger <- result.try(ledger_after(
    restored_placed,
    option.is_some(restored_managed),
    ports,
  ))
  let names = managed_names(option.unwrap(restored_managed, existing_managed))
  placed_ledger_reconciliation.excess_to_prune(query.owned, ledger)
  |> list.try_map(name_location(_, names))
}
