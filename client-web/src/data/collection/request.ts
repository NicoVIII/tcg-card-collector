import { skirClient } from "../http/skir_rpc";
import {
  ListCollectionCards,
  ListCollectionCardsRequest,
  CollectionCardList as RpcCollectionCardList,
  CollectionCopy as RpcCollectionCopy,
} from "../skirout/collection/queries.js";
import { fromWireFinishKind, fromWireLanguageKind, type Finish, type Language } from "./copy_kind";

export type CollectionCopy = {
  finish: Finish;
  language: Language;
  quantity: number;
};

export type CollectionCard = {
  set_code: string;
  collector_number: string;
  copies: CollectionCopy[];
};

export type CollectionCardList = {
  data: CollectionCard[];
  total: number;
  offset: number;
  limit: number;
};

function toCollectionCopy(copy: RpcCollectionCopy): CollectionCopy {
  return {
    finish: fromWireFinishKind(copy.finish.union.kind),
    language: fromWireLanguageKind(copy.language.union.kind),
    quantity: copy.quantity,
  };
}

function toCollectionCardList(response: RpcCollectionCardList): CollectionCardList {
  return {
    data: response.data.map((card) => ({
      set_code: card.setCode,
      collector_number: card.collectorNumber,
      copies: card.copies.map(toCollectionCopy),
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
