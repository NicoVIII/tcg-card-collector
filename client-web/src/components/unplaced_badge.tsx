import { Show } from "solid-js";
import { buildGuidance } from "../data/placement/guidance";
import { useInventoryProjectionQuery } from "../data/inventory_planning/query";
import { usePlacedLedgerQuery } from "../data/placement/query";

// Derives the unplaced count from the same cached projection + placed-ledger
// queries the placement page uses, so it shares their cache rather than issuing
// a separate count RPC.
export function UnplacedBadge() {
  const projectionQuery = useInventoryProjectionQuery();
  const ledgerQuery = usePlacedLedgerQuery();

  const totalUnplaced = () => {
    const projection = projectionQuery.data;
    const ledger = ledgerQuery.data;
    if (projection === undefined || ledger === undefined) {
      return 0;
    }
    return buildGuidance(projection, ledger).total_unplaced;
  };

  return (
    <Show when={totalUnplaced() > 0}>
      <span class="nav-badge">{totalUnplaced()}</span>
    </Show>
  );
}
