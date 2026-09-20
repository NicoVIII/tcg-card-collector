import { createMutation, useQueryClient } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import {
  type CardPlacementInput,
  markCardsPlaced,
  relocatePlacedCards,
  unmarkCardsPlaced,
} from "./request";

// Marks the ledger stale without refetching it: the placement page already
// applies the tick to its session state and derives guidance from that, so a
// refetch here would only pay for a full ledger read and projection refold
// per tick to reconfirm what the page already shows (#105, ADR 0015). The
// ledger reconciles the next time something mounts it.
function markLedgerStale(queryClient: ReturnType<typeof useQueryClient>) {
  return queryClient.invalidateQueries({
    queryKey: queryKeys.placedLedger(),
    refetchType: "none",
  });
}

export function useMarkCardsPlacedMutation() {
  const queryClient = useQueryClient();

  return createMutation(() => ({
    mutationFn: (placements: CardPlacementInput[]) => markCardsPlaced(placements),
    onSuccess: () => markLedgerStale(queryClient),
  }));
}

export function useUnmarkCardsPlacedMutation() {
  const queryClient = useQueryClient();

  return createMutation(() => ({
    mutationFn: (placements: CardPlacementInput[]) => unmarkCardsPlaced(placements),
    onSuccess: () => markLedgerStale(queryClient),
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
