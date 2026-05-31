import { createMutation, useQueryClient } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import { postImportCollection, type ImportCollectionPayload } from "./request";

export function useImportCollectionMutation() {
  const queryClient = useQueryClient();

  return createMutation(() => ({
    mutationFn: (payload: ImportCollectionPayload) => postImportCollection(payload),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: queryKeys.importStatus() });
      await queryClient.refetchQueries({ queryKey: queryKeys.importStatus() });
    },
  }));
}
