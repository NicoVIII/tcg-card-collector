import { createMutation, useQueryClient } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import { markTargetSet, unmarkTargetSet } from "./request";

export function useMarkTargetSetMutation() {
  const queryClient = useQueryClient();

  return createMutation(() => ({
    mutationFn: (setCode: string) => markTargetSet(setCode),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: queryKeys.setCompletion() });
    },
  }));
}

export function useUnmarkTargetSetMutation() {
  const queryClient = useQueryClient();

  return createMutation(() => ({
    mutationFn: (setCode: string) => unmarkTargetSet(setCode),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: queryKeys.setCompletion() });
    },
  }));
}
