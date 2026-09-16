import { For, Show } from "solid-js";
import { useCardQuery } from "../data/card_catalog/query";

export type CopyBadge = {
  finish: string;
  language: string;
  quantity: number;
};

type Props = {
  set_code: string;
  collector_number: string;
  copies?: CopyBadge[];
};

// One badge per kind of copy owned, so a printing held as e.g. two nonfoil-en
// and one foil-de shows both at a glance (ADR 0010) rather than collapsing to
// a single count.
function badgeLabel(copy: CopyBadge): string {
  return `${copy.quantity}× ${copy.finish}·${copy.language}`;
}

export function CardTile(props: Props) {
  const cardQuery = useCardQuery(() => ({
    set_code: props.set_code,
    collector_number: props.collector_number,
  }));

  return (
    <div class="card-tile">
      <Show when={props.copies !== undefined && props.copies.length > 0}>
        <div class="card-badge-list">
          <For each={props.copies}>
            {(copy) => <span class="card-badge">{badgeLabel(copy)}</span>}
          </For>
        </div>
      </Show>
      <Show
        when={cardQuery.data}
        fallback={
          <div class="card-tile-placeholder">
            <span>
              {props.set_code} #{props.collector_number}
            </span>
            <Show when={!cardQuery.isLoading}>
              <span class="card-tile-unknown">Unknown card</span>
            </Show>
          </div>
        }
      >
        {(card) => (
          <>
            <img src={card().image_uri} alt={card().name} />
            <span class="card-tile-name">{card().name}</span>
          </>
        )}
      </Show>
    </div>
  );
}
