import { createQuery, useQueryClient } from "@tanstack/solid-query";
import type { CardFilter } from "../../lib/card_filter";
import { queryKeys } from "../query-keys/factory";
import { getOwnedCopies, listCollectionCards } from "./request";

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

// Imperative rather than a reactive query: staging asks once per submitted
// entry, and must see the collection as it is now, not a cached copy.
export function useFetchOwnedCopies() {
  const queryClient = useQueryClient();

  return (setCode: string, collectorNumber: string) =>
    queryClient.fetchQuery({
      queryKey: queryKeys.collectionOwned(setCode, collectorNumber),
      queryFn: () => getOwnedCopies(setCode, collectorNumber),
      staleTime: 0,
    });
}
