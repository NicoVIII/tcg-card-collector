import { createMutation, useQueryClient } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import { refreshCatalog } from "./request";

export function useRefreshCatalogMutation() {
  const queryClient = useQueryClient();

  return createMutation(() => ({
    mutationFn: refreshCatalog,
    onSuccess: async () => {
      // Matches the ["card_catalog", "refresh_status"] key too (prefix match).
      await queryClient.invalidateQueries({ queryKey: ["card_catalog"] });
      await queryClient.invalidateQueries({ queryKey: queryKeys.settings() });
    },
  }));
}
