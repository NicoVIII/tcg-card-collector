import { For, Show, createSignal } from "solid-js";
import { mapError } from "../data/http/error";
import { useRefreshCatalogMutation } from "../data/card_catalog/mutation";
import { useCatalogCardsQuery } from "../data/card_catalog/query";

export function CatalogPage() {
  const [offset, setOffset] = createSignal(0);
  const [limit] = createSignal(25);
  const cardsQuery = useCatalogCardsQuery(offset, limit);
  const refreshMutation = useRefreshCatalogMutation();

  const total = () => cardsQuery.data?.total ?? 0;
  const hasMore = () => offset() + limit() < total();
  const hasPrev = () => offset() > 0;

  return (
    <section>
      <h2>Catalog</h2>
      <button onClick={() => refreshMutation.mutate()} disabled={refreshMutation.isPending}>
        Refresh catalog
      </button>
      <Show when={cardsQuery.isLoading}>
        <p>Loading cards...</p>
      </Show>
      <Show when={cardsQuery.isError}>
        <p role="alert">{mapError(cardsQuery.error).message}</p>
      </Show>
      <Show
        when={(cardsQuery.data?.data?.length ?? 0) > 0}
        fallback={
          <Show when={!cardsQuery.isLoading}>
            <p>No cards found.</p>
          </Show>
        }
      >
        <ul>
          <For each={cardsQuery.data?.data}>
            {(card) => (
              <li>
                {card.name} ({card.set_code})
              </li>
            )}
          </For>
        </ul>
        <div>
          <button onClick={() => setOffset(offset() - limit())} disabled={!hasPrev()}>
            Prev
          </button>
          <span>
            {offset() + 1}–{Math.min(offset() + limit(), total())} of {total()}
          </span>
          <button onClick={() => setOffset(offset() + limit())} disabled={!hasMore()}>
            Next
          </button>
        </div>
      </Show>
    </section>
  );
}
