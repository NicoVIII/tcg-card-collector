import { For } from "solid-js";
import { CardTile } from "./card_tile";

type CardGridItem = {
  set_code: string;
  collector_number: string;
  quantity?: number;
};

type Props = {
  cards: CardGridItem[];
};

export function CardGrid(props: Props) {
  return (
    <div class="card-grid">
      <For each={props.cards}>
        {(card) => (
          <CardTile
            set_code={card.set_code}
            collector_number={card.collector_number}
            quantity={card.quantity}
          />
        )}
      </For>
    </div>
  );
}
