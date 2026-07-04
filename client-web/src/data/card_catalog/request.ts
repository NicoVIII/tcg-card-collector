import { z } from "zod";
import { skirClient } from "../http/skir_rpc";
import { RefreshCatalog, RefreshCatalogRequest } from "../skirout/card_catalog/commands.js";
import {
  GetCatalogCards,
  GetCatalogCardsRequest,
  CatalogCardKey as RpcCatalogCardKey,
  GetCatalogRefreshStatus,
  GetCatalogRefreshStatusRequest,
  ListCatalogCards,
  ListCatalogCardsRequest,
} from "../skirout/card_catalog/queries.js";

const RpcCatalogCardKeySchema = z.object({
  setCode: z.string(),
  collectorNumber: z.string(),
});

const RpcCatalogCardKeyListSchema = z.object({
  data: z.array(RpcCatalogCardKeySchema),
  total: z.number(),
  offset: z.number(),
  limit: z.number(),
});

const RpcCatalogCardSchema = z.object({
  setCode: z.string(),
  collectorNumber: z.string(),
  name: z.string(),
  imageUri: z.string(),
  rarity: z.string(),
  oracleId: z.string(),
  colorIdentity: z.string(),
  typeLine: z.string(),
  releasedAt: z.string(),
});

const RpcCatalogCardListSchema = z.object({
  data: z.array(RpcCatalogCardSchema),
});

export type CatalogCardKey = {
  set_code: string;
  collector_number: string;
};

export type CatalogCard = {
  set_code: string;
  collector_number: string;
  name: string;
  image_uri: string;
  rarity: string;
  oracle_id: string;
  color_identity: string;
  type_line: string;
  released_at: string;
};

export type CatalogCardKeyList = {
  data: CatalogCardKey[];
  total: number;
  offset: number;
  limit: number;
};

function toCatalogCardKey(rpc: z.infer<typeof RpcCatalogCardKeySchema>): CatalogCardKey {
  return { set_code: rpc.setCode, collector_number: rpc.collectorNumber };
}

function toCatalogCard(rpc: z.infer<typeof RpcCatalogCardSchema>): CatalogCard {
  return {
    set_code: rpc.setCode,
    collector_number: rpc.collectorNumber,
    name: rpc.name,
    image_uri: rpc.imageUri,
    rarity: rpc.rarity,
    oracle_id: rpc.oracleId,
    color_identity: rpc.colorIdentity,
    type_line: rpc.typeLine,
    released_at: rpc.releasedAt,
  };
}

function toCatalogCardKeyList(
  response: z.infer<typeof RpcCatalogCardKeyListSchema>,
): CatalogCardKeyList {
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
  return toCatalogCardKeyList(RpcCatalogCardKeyListSchema.parse(response));
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
  return RpcCatalogCardListSchema.parse(response).data.map(toCatalogCard);
}

export type CatalogRefreshStatus = {
  status: string;
  last_probe_at: string;
  last_upstream_updated_at: string;
  error_message: string;
};

export async function getCatalogRefreshStatus(): Promise<CatalogRefreshStatus> {
  const response = await skirClient.invokeRemote(
    GetCatalogRefreshStatus,
    GetCatalogRefreshStatusRequest.create({ unit: true }),
    "POST",
  );

  return {
    status: response.status,
    last_probe_at: response.lastProbeAt,
    last_upstream_updated_at: response.lastUpstreamUpdatedAt,
    error_message: response.errorMessage,
  };
}

export type RefreshCatalogResult = { kind: "started" | "already_running" };

export async function refreshCatalog(): Promise<RefreshCatalogResult> {
  const response = await skirClient.invokeRemote(
    RefreshCatalog,
    RefreshCatalogRequest.create({ unit: true }),
  );
  return { kind: response.union.kind === "ALREADY_RUNNING" ? "already_running" : "started" };
}
