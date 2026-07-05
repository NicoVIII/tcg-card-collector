import { Show } from "solid-js";
import { usePlacementGuidanceQuery } from "../data/placement/query";

// Reuses the placement guidance query, so it shares a cache entry with the
// placement page rather than issuing a second count RPC.
export function UnplacedBadge() {
  const guidanceQuery = usePlacementGuidanceQuery();

  return (
    <Show when={(guidanceQuery.data?.total_unplaced ?? 0) > 0}>
      <span class="nav-badge">{guidanceQuery.data?.total_unplaced}</span>
    </Show>
  );
}
