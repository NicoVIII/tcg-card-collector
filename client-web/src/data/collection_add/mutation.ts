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
      // An add is persisted as an import run, so the import page's status
      // line would go stale without this.
      await queryClient.invalidateQueries({ queryKey: queryKeys.importStatus() });
    },
  }));
}
