import { createMutation, useQueryClient } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import { refreshCatalog } from "./request";

export function useRefreshCatalogMutation() {
  const queryClient = useQueryClient();

  return createMutation(() => ({
    mutationFn: refreshCatalog,
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: queryKeys.catalogRefreshStatus() });
    },
  }));
}
