import { Show, createSignal } from "solid-js";
import { useRefreshCatalogMutation } from "../data/card_catalog/mutation";
import { useCatalogCardsQuery, useCatalogRefreshStatusQuery } from "../data/card_catalog/query";
import { mapError } from "../data/http/error";
import { CardGrid } from "../components/card_grid";
import { Pagination } from "../components/pagination";

const PAGE_SIZE = 25;

export function CatalogPage() {
  const [offset, setOffset] = createSignal(0);
  const [refreshFeedback, setRefreshFeedback] = createSignal<
    { kind: "success" | "error"; message: string } | undefined
  >(undefined);
  const keysQuery = useCatalogCardsQuery(offset, () => PAGE_SIZE);
  const refreshMutation = useRefreshCatalogMutation();
  const refreshStatusQuery = useCatalogRefreshStatusQuery();

  const total = () => keysQuery.data?.total ?? 0;

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
      <Show when={refreshStatusQuery.data && refreshStatusQuery.data.status !== "never_run"}>
        <p>
          Last refresh: {refreshStatusQuery.data?.status} ({refreshStatusQuery.data?.last_probe_at})
          <Show when={refreshStatusQuery.data?.error_message}>
            {" — "}
            {refreshStatusQuery.data?.error_message}
          </Show>
        </p>
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
