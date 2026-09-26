import { For, Show } from "solid-js";

const REJECTED_DISPLAY_LIMIT = 20;

export type RejectedItem = {
  label: string;
  reason: string;
};

// The capped "N skipped" report for import surfaces that reject individual
// rows/entries while the rest still import (backup_page's own-format
// entries) — label is neutral so each caller supplies its own identifier
// shape ("Entry 12 (mh2 17 foill en)").
export function RejectedList(props: { items: RejectedItem[] }) {
  return (
    <Show when={props.items.length > 0}>
      <p>{props.items.length} skipped:</p>
      <ul>
        <For each={props.items.slice(0, REJECTED_DISPLAY_LIMIT)}>
          {(item) => (
            <li>
              {item.label}: {item.reason}
            </li>
          )}
        </For>
      </ul>
      <Show when={props.items.length > REJECTED_DISPLAY_LIMIT}>
        <p>…and {props.items.length - REJECTED_DISPLAY_LIMIT} more.</p>
      </Show>
    </Show>
  );
}
