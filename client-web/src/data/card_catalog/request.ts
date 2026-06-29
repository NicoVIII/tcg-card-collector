import { skirClient } from "../http/skir_rpc";
import {
  GetCatalogCards,
  GetCatalogCardsRequest,
  CatalogCardKey as RpcCatalogCardKey,
  ListCatalogCards,
  ListCatalogCardsRequest,
  CatalogCardKeyList as RpcCatalogCardKeyList,
  CatalogCard as RpcCatalogCard,
} from "../skirout/card_catalog/queries.js";

export type CatalogCardKey = {
  set_code: string;
  collector_number: string;
};

export type CatalogCard = {
  set_code: string;
  collector_number: string;
  name: string;
  image_uri: string;
};

export type CatalogCardKeyList = {
  data: CatalogCardKey[];
  total: number;
  offset: number;
  limit: number;
};

function toCatalogCardKey(rpc: RpcCatalogCardKey): CatalogCardKey {
  return { set_code: rpc.setCode, collector_number: rpc.collectorNumber };
}

function toCatalogCard(rpc: RpcCatalogCard): CatalogCard {
  return {
    set_code: rpc.setCode,
    collector_number: rpc.collectorNumber,
    name: rpc.name,
    image_uri: rpc.imageUri,
  };
}

function toCatalogCardKeyList(response: RpcCatalogCardKeyList): CatalogCardKeyList {
  return {
    data: response.data.map(toCatalogCardKey),
    total: response.total,
    offset: response.offset,
    limit: response.limit,
  };
}

export async function listCatalogCards(offset: number, limit: number): Promise<CatalogCardKeyList> {
  const response = await skirClient.invokeRemote(
    ListCatalogCards,
    ListCatalogCardsRequest.create({ offset, limit }),
    "POST",
  );
  return toCatalogCardKeyList(response);
}

export async function getCatalogCards(keys: CatalogCardKey[]): Promise<CatalogCard[]> {
  const response = await skirClient.invokeRemote(
    GetCatalogCards,
    GetCatalogCardsRequest.create({
      keys: keys.map((k) =>
        RpcCatalogCardKey.create({ setCode: k.set_code, collectorNumber: k.collector_number }),
      ),
    }),
    "POST",
  );
  return response.data.map(toCatalogCard);
}

export async function refreshCatalog(): Promise<{ success: boolean; message: string }> {
  const refreshTimeoutMs = 90_000;
  const refreshEndpoint = "/api/catalog/refresh";

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
