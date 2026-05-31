import { createQuery } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import { listCatalogCards } from "./request";

export function useCatalogCardsQuery(offset: () => number, limit: () => number) {
  return createQuery(() => ({
    queryKey: queryKeys.catalogList(offset(), limit()),
    queryFn: () => listCatalogCards(offset(), limit()),
  }));
}
