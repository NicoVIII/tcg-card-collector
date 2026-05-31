import { requestJson } from "../http/request";

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

export async function listCatalogCards(offset: number, limit: number): Promise<CatalogCardList> {
  return requestJson<CatalogCardList>(`/api/catalog/cards?offset=${offset}&limit=${limit}`);
}

export async function refreshCatalog(): Promise<{ success: boolean }> {
  return requestJson<{ success: boolean }>("/api/catalog/refresh", {
    method: "POST",
  });
}
