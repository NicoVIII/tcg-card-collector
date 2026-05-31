import { createMutation, useQueryClient } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import { deleteInventoryRule, upsertInventoryRule, type InventoryRule } from "./request";

export function useUpsertInventoryRuleMutation() {
  const queryClient = useQueryClient();

  return createMutation(() => ({
    mutationFn: (rule: InventoryRule) => upsertInventoryRule(rule),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: queryKeys.inventoryRules() });
      await queryClient.invalidateQueries({ queryKey: ["inventory_planning", "projection"] });
    },
  }));
}

export function useDeleteInventoryRuleMutation() {
  const queryClient = useQueryClient();

  return createMutation(() => ({
    mutationFn: (id: string) => deleteInventoryRule(id),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: queryKeys.inventoryRules() });
      await queryClient.invalidateQueries({ queryKey: ["inventory_planning", "projection"] });
    },
  }));
}
