import inventory_planning/application/queries/predict_restore_prune/ports
import inventory_planning/infrastructure/adapters/commands/reconcile_placed_ledger/adapter as reconcile_placed_ledger_adapter
import inventory_planning/infrastructure/daos/managed_locations_dao

// The ledger read is the reconcile's own, so the prediction prunes the rows
// the reconcile will see.
pub fn new() -> ports.PredictRestorePrunePorts {
  ports.PredictRestorePrunePorts(
    list_placed: reconcile_placed_ledger_adapter.new().list_placed,
    list_managed_locations: managed_locations_dao.load_all,
  )
}
