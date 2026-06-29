import { Show } from "solid-js";
import { useCardQuery } from "../data/card_catalog/query";

type Props = {
  set_code: string;
  collector_number: string;
  quantity?: number;
};

export function CardTile(props: Props) {
  const cardQuery = useCardQuery(() => ({
    set_code: props.set_code,
    collector_number: props.collector_number,
  }));

  return (
    <div class="card-tile">
      <Show when={props.quantity !== undefined}>
        <span class="card-badge">&times;{props.quantity}</span>
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
