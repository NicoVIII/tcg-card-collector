import { createMutation, useQueryClient } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import { postRemoveCards, type RemoveCardsPayload } from "./request";

export function useRemoveCardsMutation() {
  const queryClient = useQueryClient();

  return createMutation(() => ({
    mutationFn: (payload: RemoveCardsPayload) => postRemoveCards(payload),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: queryKeys.collection() });
      await queryClient.invalidateQueries({ queryKey: queryKeys.setCompletion() });
      await queryClient.invalidateQueries({ queryKey: queryKeys.inventoryProjection() });
      // Unlike AddCards, a removal can shrink the placed ledger too (ADR
      // 0011's reconciliation), so this invalidates it as well.
      await queryClient.invalidateQueries({ queryKey: queryKeys.placedLedger() });
    },
  }));
}
