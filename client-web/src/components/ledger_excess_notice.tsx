import { For, Show } from "solid-js";
import type { LedgerExcess } from "../data/portability/request";

// What a restore's placed ledger will lose right after import: any copy
// placed beyond what the file's own collection owns gets pruned by the
// server's existing ReconcilePlacedLedger (ADR 0011) — this says so before
// the user confirms, rather than only after.
export function LedgerExcessNotice(props: { excess: LedgerExcess[] }) {
  const unit = () => (props.excess.length === 1 ? "copy" : "copies");

  return (
    <Show when={props.excess.length > 0}>
      <p role="alert">
        {props.excess.length} placed {unit()} exceed the collection this file will restore and will
        be removed from the ledger afterward:
      </p>
      <ul>
        <For each={props.excess}>
          {(entry) => (
            <li>
              {entry.identity}: placed {entry.placed}, owned {entry.owned}
            </li>
          )}
        </For>
      </ul>
    </Show>
  );
}
