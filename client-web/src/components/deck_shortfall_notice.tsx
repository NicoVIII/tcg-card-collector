import { For, Show } from "solid-js";
import type { DeckShortfall } from "../data/portability/request";

// What a restore's decks will be missing right after import: a deck keeps
// its whole list, but the file's own collection owns fewer copies than the
// decks claim (ADR 0022). Said before the user confirms, the same posture as
// LedgerExcessNotice — nothing is lost, but a deck coming up short should
// never be a surprise.
export function DeckShortfallNotice(props: { shortfall: DeckShortfall[] }) {
  return (
    <Show when={props.shortfall.length > 0}>
      <p role="alert">
        The collection this file will restore doesn't own every card its decks list; these decks
        will be short afterward:
      </p>
      <ul>
        <For each={props.shortfall}>
          {(entry) => (
            <li>
              {entry.location_name}: {entry.missing} × {entry.identity} missing
            </li>
          )}
        </For>
      </ul>
    </Show>
  );
}
