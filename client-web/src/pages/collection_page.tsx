import { Show, createSignal } from "solid-js";
import { A } from "@solidjs/router";
import { useCollectionCardsQuery } from "../data/collection/query";
import { mapError } from "../data/http/error";
import { CardGrid } from "../components/card_grid";
import { Pagination } from "../components/pagination";
import { AddCardsPanel } from "./add_cards_panel";

const PAGE_SIZE = 25;

export function CollectionPage() {
  const [offset, setOffset] = createSignal(0);
  const cardsQuery = useCollectionCardsQuery(offset, () => PAGE_SIZE);

  const total = () => cardsQuery.data?.total ?? 0;

  return (
    <section>
      <div class="page-heading">
        <h2>Collection</h2>
        <A href="/collection/import">Import / reset collection…</A>
      </div>
      <AddCardsPanel />
      <Show when={cardsQuery.isLoading}>
        <p>Loading collection...</p>
      </Show>
      <Show when={cardsQuery.isError}>
        <p role="alert">{mapError(cardsQuery.error).message}</p>
      </Show>
      <Show
        when={(cardsQuery.data?.data?.length ?? 0) > 0}
        fallback={
          <Show when={!cardsQuery.isLoading}>
            <p>No cards in collection.</p>
          </Show>
        }
      >
        <CardGrid cards={cardsQuery.data?.data ?? []} />
        <Pagination
          offset={offset()}
          limit={PAGE_SIZE}
          total={total()}
          onOffsetChange={setOffset}
        />
      </Show>
    </section>
  );
}
