import gleam/result
import inventory_planning/application/commands/reconcile_placed_ledger/ports
import inventory_planning/domain/placed_ledger_reconciliation
import shared/application/command_result

/// Triggered only as an event-bus subscriber (ADR 0011) — there is no skir
/// method or REST route for this command, since nothing outside the process
/// ever needs to invoke it directly.
pub type ReconcilePlacedLedgerCommand {
  ReconcilePlacedLedgerCommand
}

/// Reconciles the whole placed ledger against the whole collection: any key
/// whose placed total exceeds what's owned gets pruned back down (ADR 0011).
/// A key already within bounds costs nothing beyond the read.
pub fn execute(
  _command: ReconcilePlacedLedgerCommand,
  ports: ports.ReconcilePlacedLedgerPorts,
) -> command_result.CommandResult(ports.ReconcilePlacedLedgerError) {
  use owned <- result.try(
    ports.owned_quantities() |> result.map_error(ports.PersistenceFailed),
  )
  use placed <- result.try(
    ports.list_placed() |> result.map_error(ports.PersistenceFailed),
  )

  placed_ledger_reconciliation.excess_to_prune(owned, placed)
  |> ports.decrement_placed
  |> result.map_error(ports.PersistenceFailed)
}
