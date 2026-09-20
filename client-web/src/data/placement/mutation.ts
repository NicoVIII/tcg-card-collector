import { createMutation, useQueryClient } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import {
  type CardPlacementInput,
  markCardsPlaced,
  relocatePlacedCards,
  unmarkCardsPlaced,
} from "./request";

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

export function useRelocatePlacedCardsMutation() {
  const queryClient = useQueryClient();

  return createMutation(() => ({
    // The projection is untouched by a relocation — only the ledger moved.
    mutationFn: (relocation: { from_location: string; to_location: string }) =>
      relocatePlacedCards(relocation.from_location, relocation.to_location),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: queryKeys.placedLedger() });
    },
  }));
}
