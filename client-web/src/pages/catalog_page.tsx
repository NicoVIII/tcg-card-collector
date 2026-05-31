import { For, Show, createSignal } from "solid-js";
import { useRefreshCatalogMutation } from "../data/card_catalog/mutation";
import { useCatalogCardsQuery } from "../data/card_catalog/query";
import { mapError } from "../data/http/error";

export function CatalogPage() {
  const [offset, setOffset] = createSignal(0);
  const [limit] = createSignal(25);
  const [refreshFeedback, setRefreshFeedback] = createSignal<
    { kind: "success" | "error"; message: string } | undefined
  >(undefined);
  const cardsQuery = useCatalogCardsQuery(offset, limit);
  const refreshMutation = useRefreshCatalogMutation();

  const total = () => cardsQuery.data?.total ?? 0;
  const hasMore = () => offset() + limit() < total();
  const hasPrev = () => offset() > 0;

  const refreshCatalog = async () => {
    setRefreshFeedback(undefined);

    try {
      const response = await refreshMutation.mutateAsync();
      await cardsQuery.refetch();

      if (!response.success) {
        setRefreshFeedback({
          kind: "error",
          message: "Catalog refresh failed on the backend.",
        });
        return;
      }

      if ((cardsQuery.data?.total ?? 0) === 0) {
        setRefreshFeedback({
          kind: "error",
          message:
            "Refresh finished, but no cards are available. The backend refresh adapter is currently not populating catalog data.",
        });
        return;
      }

      setRefreshFeedback({
        kind: "success",
        message: `Catalog refreshed. Loaded ${cardsQuery.data?.total ?? 0} cards.`,
      });
    } catch (error) {
      setRefreshFeedback({
        kind: "error",
        message: `Catalog refresh failed: ${mapError(error).message}`,
      });
    }
  };

  return (
    <section>
      <h2>Catalog</h2>
      <button onClick={refreshCatalog} disabled={refreshMutation.isPending}>
        Refresh catalog
      </button>
      <Show when={refreshMutation.isPending}>
        <p>Refreshing catalog...</p>
      </Show>
      <Show when={refreshFeedback()}>
        {(feedback) => (
          <p role={feedback().kind === "error" ? "alert" : "status"}>{feedback().message}</p>
        )}
      </Show>
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
