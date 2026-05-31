import { skirClient } from "../http/skir_rpc";
import { RefreshCatalog, RefreshCatalogRequest } from "../skirout/card_catalog/commands.js";
import {
  ListCatalogCards,
  ListCatalogCardsRequest,
  CatalogCardList as RpcCatalogCardList,
} from "../skirout/card_catalog/queries.js";

const refreshTimeoutMs = 120_000;

export type CatalogCard = {
  id: string;
  name: string;
  set_code: string;
};

export type CatalogCardList = {
  data: CatalogCard[];
  total: number;
  offset: number;
  limit: number;
};

function toCatalogCardList(response: RpcCatalogCardList): CatalogCardList {
  return {
    data: response.data.map((card) => ({
      id: card.id,
      name: card.name,
      set_code: card.setCode,
    })),
    total: response.total,
    offset: response.offset,
    limit: response.limit,
  };
}

export async function listCatalogCards(offset: number, limit: number): Promise<CatalogCardList> {
  const response = await skirClient.invokeRemote(
    ListCatalogCards,
    ListCatalogCardsRequest.create({ offset, limit }),
    "POST",
  );

  return toCatalogCardList(response);
}

export async function refreshCatalog(): Promise<{ success: boolean }> {
  const response = await withTimeout(
    skirClient.invokeRemote(RefreshCatalog, RefreshCatalogRequest.create({ unit: true })),
    refreshTimeoutMs,
    "Catalog refresh timed out. Please try again.",
  );

  return { success: response.union.kind === "SUCCESS" };
}

async function withTimeout<T>(
  promise: Promise<T>,
  timeoutMs: number,
  timeoutMessage: string,
): Promise<T> {
  let timeoutId: ReturnType<typeof setTimeout> | undefined;
  const timeoutPromise = new Promise<never>((_, reject) => {
    timeoutId = setTimeout(() => reject(new Error(timeoutMessage)), timeoutMs);
  });

  try {
    return await Promise.race([promise, timeoutPromise]);
  } finally {
    if (timeoutId !== undefined) {
      clearTimeout(timeoutId);
    }
  }
}
