import { createMutation, useQueryClient } from "@tanstack/solid-query";
import { invalidateCollectionDependents } from "../collection/invalidate";
import { postRemoveCards, type RemoveCardsPayload } from "./request";

export function useRemoveCardsMutation() {
  const queryClient = useQueryClient();

  return createMutation(() => ({
    mutationFn: (payload: RemoveCardsPayload) => postRemoveCards(payload),
    onSuccess: () => invalidateCollectionDependents(queryClient),
  }));
}
