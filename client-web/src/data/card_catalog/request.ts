import { RefreshCatalog, RefreshCatalogRequest } from "../skirout/card_catalog/commands.js";
import {
  CatalogCardList as RpcCatalogCardList,
  ListCatalogCards,
  ListCatalogCardsRequest,
} from "../skirout/card_catalog/queries.js";
import { skirClient } from "../http/skir_rpc";

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
  const response = await skirClient.invokeRemote(
    RefreshCatalog,
    RefreshCatalogRequest.create({ unit: true }),
  );

  return { success: response.union.kind === "SUCCESS" };
}
