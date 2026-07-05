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
      await queryClient.invalidateQueries({ queryKey: queryKeys.placementGuidance() });
    },
  }));
}
