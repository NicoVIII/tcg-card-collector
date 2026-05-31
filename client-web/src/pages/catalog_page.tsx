import { createSignal } from "solid-js";
import { useRefreshCatalogMutation } from "../data/card_catalog/mutation";
import { useCatalogCardsQuery } from "../data/card_catalog/query";

export function CatalogPage() {
  const [offset, setOffset] = createSignal(0);
  const [limit] = createSignal(25);
  const cardsQuery = useCatalogCardsQuery(offset, limit);
  const refreshMutation = useRefreshCatalogMutation();

  return (
    <section>
      <h2>Catalog</h2>
      <button onClick={() => refreshMutation.mutate()} disabled={refreshMutation.isPending}>
        Refresh catalog
      </button>
      <button onClick={() => setOffset(Math.max(0, offset() - limit()))}>Prev</button>
      <button onClick={() => setOffset(offset() + limit())}>Next</button>
      <pre>{JSON.stringify(cardsQuery.data, null, 2)}</pre>
    </section>
  );
}
