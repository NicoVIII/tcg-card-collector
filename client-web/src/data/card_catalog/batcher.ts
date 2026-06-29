import { create, windowScheduler } from "@yornaath/batshit";
import { type CatalogCard, type CatalogCardKey, getCatalogCards } from "./request";

// Batches per-card fetches triggered within the same animation frame into a
// single GetCatalogCards RPC call. The resolver matches each key to its result
// by set_code + collector_number.
export const cardBatcher = create<CatalogCard[], CatalogCardKey, CatalogCard | undefined>({
  fetcher: getCatalogCards,
  resolver: (cards: CatalogCard[], key: CatalogCardKey) =>
    cards.find(
      (card) => card.set_code === key.set_code && card.collector_number === key.collector_number,
    ),
  scheduler: windowScheduler(10),
});
