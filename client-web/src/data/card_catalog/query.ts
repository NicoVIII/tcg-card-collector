import { createQuery } from "@tanstack/solid-query";
import { cardBatcher } from "./batcher";
import {
  type CatalogCard,
  type CatalogCardKey,
  getCatalogRefreshStatus,
  listCatalogCards,
} from "./request";
import { queryKeys } from "../query-keys/factory";

export function useCatalogCardsQuery(offset: () => number, limit: () => number) {
  return createQuery(() => ({
    queryKey: queryKeys.catalogList(offset(), limit()),
    queryFn: () => listCatalogCards(offset(), limit()),
  }));
}

export function useCatalogRefreshStatusQuery(refetchIntervalMs?: () => number | false) {
  return createQuery(() => ({
    queryKey: queryKeys.catalogRefreshStatus(),
    queryFn: getCatalogRefreshStatus,
    refetchInterval: refetchIntervalMs?.() ?? false,
  }));
}

export function useCardQuery(key: () => CatalogCardKey) {
  return createQuery(() => ({
    queryKey: queryKeys.card(key().set_code, key().collector_number),
    queryFn: async (): Promise<CatalogCard | null> => {
      const result = await cardBatcher.fetch(key());
      return result ?? null;
    },
  }));
}
