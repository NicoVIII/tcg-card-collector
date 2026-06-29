import { createQuery } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import { listCollectionCards } from "./request";

export function useCollectionCardsQuery(offset: () => number, limit: () => number) {
  return createQuery(() => ({
    queryKey: queryKeys.collectionList(offset(), limit()),
    queryFn: () => listCollectionCards(offset(), limit()),
  }));
}
