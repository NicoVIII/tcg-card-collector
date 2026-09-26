import { Show, createMemo, createSignal } from "solid-js";
import { A, useSearchParams } from "@solidjs/router";
import { useCollectionCardsQuery } from "../data/collection/query";
import { mapError } from "../data/http/error";
import { CardGrid } from "../components/card_grid";
import { CardSearchForm } from "../components/card_search_form";
import { Pagination } from "../components/pagination";
import {
  type CardFilter,
  filterFromSearchParams,
  searchParamsFromFilter,
} from "../lib/card_filter";
import { AddCardsPanel } from "./add_cards_panel";
import { RemoveCardsPanel } from "./remove_cards_panel";

const PAGE_SIZE = 25;

export function CollectionPage() {
  const [searchParams, setSearchParams] = useSearchParams<{ name?: string; set?: string }>();
  const filter = createMemo(() => filterFromSearchParams(searchParams));
  const [offset, setOffset] = createSignal(0);
  const cardsQuery = useCollectionCardsQuery(filter, offset, () => PAGE_SIZE);
  const isFiltered = () => filter().name !== "" || filter().set_code !== "";

  const total = () => cardsQuery.data?.total ?? 0;

  const search = (next: CardFilter) => {
    setOffset(0);
    setSearchParams(searchParamsFromFilter(next));
  };

  return (
    <section>
      <div class="page-heading">
        <h2>Collection</h2>
        <A href="/backup">Back up & restore…</A>
      </div>
      <AddCardsPanel />
      <RemoveCardsPanel />
      <CardSearchForm filter={filter()} onSearch={search} />
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
            <p>{isFiltered() ? "No cards match your search." : "No cards in collection."}</p>
          </Show>
        }
      >
        <CardGrid
          cards={(cardsQuery.data?.data ?? []).map((card) => ({
            set_code: card.set_code,
            collector_number: card.collector_number,
            copies: card.copies,
          }))}
        />
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
