import { createQuery } from "@tanstack/solid-query";
import type { CardFilter } from "../../lib/card_filter";
import { queryKeys } from "../query-keys/factory";
import { listCollectionCards } from "./request";

export function useCollectionCardsQuery(
  filter: () => CardFilter,
  offset: () => number,
  limit: () => number,
) {
  return createQuery(() => ({
    queryKey: queryKeys.collectionList(filter(), offset(), limit()),
    queryFn: () => listCollectionCards(filter(), offset(), limit()),
  }));
}
