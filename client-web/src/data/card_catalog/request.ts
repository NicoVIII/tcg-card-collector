import { skirClient } from "../http/skir_rpc";
import {
  ListCatalogCards,
  ListCatalogCardsRequest,
  CatalogCardList as RpcCatalogCardList,
} from "../skirout/card_catalog/queries.js";

const refreshTimeoutMs = 90_000;
const refreshEndpoint = "/api/catalog/refresh";

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

export async function refreshCatalog(): Promise<{ success: boolean; message: string }> {
  const response = await withTimeout(
    fetch(refreshEndpoint, { method: "POST" }),
    refreshTimeoutMs,
    "Catalog refresh is still running on the server. Please check again in a moment.",
  );

  const payload = (await response.json()) as { ok?: string; error?: string };

  if (response.ok) {
    return {
      success: true,
      message: payload.ok ?? "Catalog refresh started.",
    };
  }

  throw new Error(payload.error ?? `Catalog refresh failed (status ${response.status})`);
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
