import { createMutation, useQueryClient } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import { type AddCardsPayload, postAddCards } from "./request";

export function useAddCardsMutation() {
  const queryClient = useQueryClient();

  return createMutation(() => ({
    mutationFn: (payload: AddCardsPayload) => postAddCards(payload),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: queryKeys.collection() });
      await queryClient.invalidateQueries({ queryKey: queryKeys.setCompletion() });
      // Adding cards changes the projection, not the placed ledger; placement
      // guidance is now derived from the projection client-side.
      await queryClient.invalidateQueries({ queryKey: queryKeys.inventoryProjection() });
    },
  }));
}
