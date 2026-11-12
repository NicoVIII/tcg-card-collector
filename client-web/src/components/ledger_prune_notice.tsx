import { For, Show } from "solid-js";
import type { LedgerPrune, PlacedIn } from "../data/portability/request";

function locationLabel(location: PlacedIn): string {
  return location.kind === "managed" ? `deck ${location.name}` : location.name;
}

// The placed-ledger rows a restore prunes right after import (ADR 0011),
// each with the location that loses them: said before the user confirms,
// and again after, because the server picks those locations by a fixed
// order — if the copies physically left elsewhere, these are the places
// to check and correct.
export function LedgerPruneNotice(props: { pruned: LedgerPrune[]; done: boolean }) {
  const unit = () => (props.pruned.length === 1 ? "row" : "rows");

  return (
    <Show when={props.pruned.length > 0}>
      <p role="alert">
        <Show
          when={props.done}
          fallback={
            <>
              The collection this file will restore owns fewer copies than are placed, so{" "}
              {props.pruned.length} placed-ledger {unit()} will be removed afterward:
            </>
          }
        >
          {props.pruned.length} placed-ledger {unit()} were removed because the restored collection
          owns fewer copies. Check these locations and correct the ledger if the copies left from
          somewhere else:
        </Show>
      </p>
      <ul>
        <For each={props.pruned}>
          {(entry) => (
            <li>
              {entry.identity}: {entry.quantity} from {locationLabel(entry.location)}
            </li>
          )}
        </For>
      </ul>
    </Show>
  );
}
