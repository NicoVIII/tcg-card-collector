import { skirClient } from "../http/skir_rpc";
import {
  ListCollectionCards,
  ListCollectionCardsRequest,
  CollectionCardList as RpcCollectionCardList,
} from "../skirout/collection/queries.js";

export type CollectionCard = {
  set_code: string;
  collector_number: string;
  quantity: number;
};

export type CollectionCardList = {
  data: CollectionCard[];
  total: number;
  offset: number;
  limit: number;
};

function toCollectionCardList(response: RpcCollectionCardList): CollectionCardList {
  return {
    data: response.data.map((card) => ({
      set_code: card.setCode,
      collector_number: card.collectorNumber,
      quantity: card.quantity,
    })),
    total: response.total,
    offset: response.offset,
    limit: response.limit,
  };
}

export async function listCollectionCards(
  offset: number,
  limit: number,
): Promise<CollectionCardList> {
  const response = await skirClient.invokeRemote(
    ListCollectionCards,
    ListCollectionCardsRequest.create({ offset, limit }),
    "POST",
  );

  return toCollectionCardList(response);
}
