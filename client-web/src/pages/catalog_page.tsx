import { Show, createSignal } from "solid-js";
import { useRefreshCatalogMutation } from "../data/card_catalog/mutation";
import { useCatalogCardsQuery } from "../data/card_catalog/query";
import { mapError } from "../data/http/error";
import { CardGrid } from "../components/card_grid";

export function CatalogPage() {
  const [offset, setOffset] = createSignal(0);
  const [limit] = createSignal(25);
  const [refreshFeedback, setRefreshFeedback] = createSignal<
    { kind: "success" | "error"; message: string } | undefined
  >(undefined);
  const keysQuery = useCatalogCardsQuery(offset, limit);
  const refreshMutation = useRefreshCatalogMutation();

  const total = () => keysQuery.data?.total ?? 0;
  const hasMore = () => offset() + limit() < total();
  const hasPrev = () => offset() > 0;

  const refreshCatalog = async () => {
    setRefreshFeedback(undefined);

    try {
      const response = await refreshMutation.mutateAsync();
      await keysQuery.refetch();

      if (!response.success) {
        setRefreshFeedback({
          kind: "error",
          message: "Catalog refresh failed on the backend.",
        });
        return;
      }

      let message = response.message;

      if ((keysQuery.data?.total ?? 0) > 0) {
        message = `${message} Current catalog rows: ${keysQuery.data?.total ?? 0}.`;
      }

      setRefreshFeedback({
        kind: "success",
        message: message,
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
      <h2>Database</h2>
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
      <Show when={keysQuery.isLoading}>
        <p>Loading cards...</p>
      </Show>
      <Show when={keysQuery.isError}>
        <p role="alert">{mapError(keysQuery.error).message}</p>
      </Show>
      <Show
        when={(keysQuery.data?.data?.length ?? 0) > 0}
        fallback={
          <Show when={!keysQuery.isLoading}>
            <p>No cards found.</p>
          </Show>
        }
      >
        <CardGrid cards={keysQuery.data?.data ?? []} />
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
