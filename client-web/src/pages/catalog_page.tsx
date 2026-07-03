import { Show, createEffect, createSignal } from "solid-js";
import { useQueryClient } from "@tanstack/solid-query";
import { useRefreshCatalogMutation } from "../data/card_catalog/mutation";
import { useCatalogCardsQuery, useCatalogRefreshStatusQuery } from "../data/card_catalog/query";
import { mapError } from "../data/http/error";
import { CardGrid } from "../components/card_grid";
import { Pagination } from "../components/pagination";

const PAGE_SIZE = 25;

export function CatalogPage() {
  const queryClient = useQueryClient();
  const [offset, setOffset] = createSignal(0);
  const [refreshFeedback, setRefreshFeedback] = createSignal<
    { kind: "success" | "error"; message: string } | undefined
  >(undefined);
  const keysQuery = useCatalogCardsQuery(offset, () => PAGE_SIZE);
  const refreshMutation = useRefreshCatalogMutation();
  // last_probe_at when a refresh started; null means we are not polling for completion.
  const [pollBaseline, setPollBaseline] = createSignal<string | null>(null);
  const refreshStatusQuery = useCatalogRefreshStatusQuery(() =>
    pollBaseline() !== null ? 2000 : false,
  );

  const total = () => keysQuery.data?.total ?? 0;

  const startRefresh = async () => {
    setRefreshFeedback(undefined);

    try {
      const result = await refreshMutation.mutateAsync();
      setPollBaseline(refreshStatusQuery.data?.last_probe_at ?? "");
      setRefreshFeedback({
        kind: "success",
        message:
          result.kind === "already_running"
            ? "A catalog refresh is already running."
            : "Catalog refresh started.",
      });
    } catch (error) {
      setRefreshFeedback({ kind: "error", message: mapError(error).message });
    }
  };

  createEffect(() => {
    const baseline = pollBaseline();
    const status = refreshStatusQuery.data;
    if (baseline === null || status === undefined) return;
    if (status.status !== "never_run" && status.last_probe_at !== baseline) {
      setPollBaseline(null);
      void queryClient.invalidateQueries({ queryKey: ["card_catalog", "list"] });
      setRefreshFeedback(
        status.status === "failed"
          ? { kind: "error", message: `Catalog refresh failed: ${status.error_message}` }
          : { kind: "success", message: `Catalog refresh ${status.status}.` },
      );
    }
  });

  return (
    <section>
      <h2>Catalog</h2>
      <button onClick={startRefresh} disabled={refreshMutation.isPending}>
        Refresh catalog
      </button>
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
