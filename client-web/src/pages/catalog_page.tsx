import { Show, createEffect, createSignal } from "solid-js";
import { useQueryClient, type QueryClient } from "@tanstack/solid-query";
import { useRefreshCatalogMutation } from "../data/card_catalog/mutation";
import { useCatalogCardsQuery, useCatalogRefreshStatusQuery } from "../data/card_catalog/query";
import type { CatalogRefreshStatus } from "../data/card_catalog/request";
import { mapError } from "../data/http/error";
import { queryKeys } from "../data/query-keys/factory";
import { CardGrid } from "../components/card_grid";
import { Pagination } from "../components/pagination";
import {
  finishedFeedback,
  hasFinishedSince,
  startedFeedback,
  type RefreshFeedback,
} from "./catalog_refresh";

const PAGE_SIZE = 25;

function formatProbeTime(iso: string): string {
  const date = new Date(iso);
  return Number.isNaN(date.getTime()) ? iso : date.toLocaleString();
}

function invalidateAfterRefresh(queryClient: QueryClient, status: CatalogRefreshStatus): void {
  void queryClient.invalidateQueries({ queryKey: queryKeys.catalogListAll() });
  if (status.status === "failed") return;
  // New catalog data changes card attributes/release dates and printed
  // set sizes, which feed the inventory projection and set-completion
  // insights; refresh both so they don't serve stale derived data.
  void queryClient.invalidateQueries({ queryKey: queryKeys.inventoryProjection() });
  void queryClient.invalidateQueries({ queryKey: queryKeys.setCompletion() });
}

function FeedbackMessage(props: { feedback: RefreshFeedback }) {
  return (
    <p
      role={props.feedback.kind === "error" ? "alert" : "status"}
      class={props.feedback.kind === "success" ? "success" : undefined}
    >
      {props.feedback.message}
    </p>
  );
}

function LastRefreshLine(props: { status: CatalogRefreshStatus }) {
  return (
    <Show when={props.status.status !== "never_run"}>
      <p>
        Last refresh: {props.status.status} ({formatProbeTime(props.status.last_probe_at)})
        <Show when={props.status.error_message}>
          {" — "}
          {props.status.error_message}
        </Show>
      </p>
    </Show>
  );
}

function CatalogCards() {
  const [offset, setOffset] = createSignal(0);
  const keysQuery = useCatalogCardsQuery(offset, () => PAGE_SIZE);
  const cards = () => keysQuery.data?.data ?? [];
  const total = () => keysQuery.data?.total ?? 0;

  return (
    <>
      <Show when={keysQuery.isLoading}>
        <p>Loading cards...</p>
      </Show>
      <Show when={keysQuery.isError}>
        <p role="alert">{mapError(keysQuery.error).message}</p>
      </Show>
      <Show
        when={cards().length > 0}
        fallback={
          <Show when={!keysQuery.isLoading}>
            <p>No cards found.</p>
          </Show>
        }
      >
        <CardGrid cards={cards()} />
        <Pagination
          offset={offset()}
          limit={PAGE_SIZE}
          total={total()}
          onOffsetChange={setOffset}
        />
      </Show>
    </>
  );
}

export function CatalogPage() {
  const queryClient = useQueryClient();
  const [refreshFeedback, setRefreshFeedback] = createSignal<RefreshFeedback | undefined>(
    undefined,
  );
  const refreshMutation = useRefreshCatalogMutation();
  // last_probe_at when a refresh started; null means we are not polling for completion.
  const [pollBaseline, setPollBaseline] = createSignal<string | null>(null);
  const refreshStatusQuery = useCatalogRefreshStatusQuery(() =>
    pollBaseline() !== null ? 2000 : false,
  );

  const startRefresh = async () => {
    setRefreshFeedback(undefined);

    try {
      const result = await refreshMutation.mutateAsync();
      setPollBaseline(refreshStatusQuery.data?.last_probe_at ?? "");
      setRefreshFeedback(startedFeedback(result));
    } catch (error) {
      setRefreshFeedback({ kind: "error", message: mapError(error).message });
    }
  };

  createEffect(() => {
    const baseline = pollBaseline();
    const status = refreshStatusQuery.data;
    if (baseline === null || status === undefined || !hasFinishedSince(status, baseline)) return;
    setPollBaseline(null);
    invalidateAfterRefresh(queryClient, status);
    setRefreshFeedback(finishedFeedback(status));
  });

  return (
    <section>
      <h2>Catalog</h2>
      <button onClick={startRefresh} disabled={refreshMutation.isPending}>
        Refresh catalog
      </button>
      <Show when={refreshFeedback()}>
        {(feedback) => <FeedbackMessage feedback={feedback()} />}
      </Show>
      <Show when={refreshStatusQuery.data}>
        {(status) => <LastRefreshLine status={status()} />}
      </Show>
      <CatalogCards />
    </section>
  );
}
