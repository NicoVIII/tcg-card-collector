import { createMutation, useQueryClient } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import { type CardPlacementInput, markCardsPlaced, unmarkCardsPlaced } from "./request";

export function useMarkCardsPlacedMutation() {
  const queryClient = useQueryClient();

  return createMutation(() => ({
    mutationFn: (placements: CardPlacementInput[]) => markCardsPlaced(placements),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: queryKeys.placedLedger() });
    },
  }));
}

export function useUnmarkCardsPlacedMutation() {
  const queryClient = useQueryClient();

  return createMutation(() => ({
    mutationFn: (placements: CardPlacementInput[]) => unmarkCardsPlaced(placements),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: queryKeys.placedLedger() });
    },
  }));
}
