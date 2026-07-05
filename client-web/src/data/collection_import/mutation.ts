import { createMutation, useQueryClient } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import { postImportCollection, type ImportCollectionPayload } from "./request";

export function useImportCollectionMutation() {
  const queryClient = useQueryClient();

  return createMutation(() => ({
    mutationFn: (payload: ImportCollectionPayload) => postImportCollection(payload),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: queryKeys.collection() });
      await queryClient.invalidateQueries({ queryKey: queryKeys.setCompletion() });
      await queryClient.invalidateQueries({ queryKey: queryKeys.placementGuidance() });
    },
  }));
}
