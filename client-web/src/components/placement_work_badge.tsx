import { Show, createMemo } from "solid-js";
import { buildGuidance } from "../data/placement/guidance";
import { useInventoryProjectionQuery } from "../data/inventory_planning/query";
import { buildResortWorklist } from "../data/placement/resort";
import { usePlacedLedgerQuery } from "../data/placement/query";

// Derives the outstanding-placement-work count from the same cached
// projection + placed-ledger queries the placement page uses, so it shares
// their cache rather than issuing a separate count RPC. Sums cards still to
// place with copies recorded somewhere the rules no longer send them (#107)
// — one badge, all the work the Place cards page has for you.
export function PlacementWorkBadge() {
  const projectionQuery = useInventoryProjectionQuery();
  const ledgerQuery = usePlacedLedgerQuery();

  const totalOutstanding = createMemo(() => {
    const projection = projectionQuery.data;
    const ledger = ledgerQuery.data;
    if (projection === undefined || ledger === undefined) {
      return 0;
    }
    return (
      buildGuidance(projection, ledger).total_unplaced +
      buildResortWorklist(projection, ledger).total_misplaced
    );
  });

  return (
    <Show when={totalOutstanding() > 0}>
      <span class="nav-badge">{totalOutstanding()}</span>
    </Show>
  );
}
