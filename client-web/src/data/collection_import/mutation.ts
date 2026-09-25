import { createMutation, useQueryClient } from "@tanstack/solid-query";
import { invalidateCollectionDependents } from "../collection/invalidate";
import { postImportCollection, type ImportCollectionPayload } from "./request";

export function useImportCollectionMutation() {
  const queryClient = useQueryClient();

  return createMutation(() => ({
    mutationFn: (payload: ImportCollectionPayload) => postImportCollection(payload),
    onSuccess: () => invalidateCollectionDependents(queryClient),
  }));
}
