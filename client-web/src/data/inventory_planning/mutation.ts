import { createMutation, useQueryClient } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import {
  deleteInventoryRule,
  updateBulkSpec,
  upsertInventoryRule,
  type BulkSpec,
  type InventoryRule,
} from "./request";

export function useUpsertInventoryRuleMutation() {
  const queryClient = useQueryClient();

  return createMutation(() => ({
    mutationFn: (rule: InventoryRule) => upsertInventoryRule(rule),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: queryKeys.inventoryRules() });
      await queryClient.invalidateQueries({ queryKey: queryKeys.inventoryProjection() });
    },
  }));
}

export function useDeleteInventoryRuleMutation() {
  const queryClient = useQueryClient();

  return createMutation(() => ({
    mutationFn: (id: string) => deleteInventoryRule(id),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: queryKeys.inventoryRules() });
      await queryClient.invalidateQueries({ queryKey: queryKeys.inventoryProjection() });
    },
  }));
}

export function useUpdateBulkSpecMutation() {
  const queryClient = useQueryClient();

  return createMutation(() => ({
    mutationFn: (spec: BulkSpec) => updateBulkSpec(spec),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: queryKeys.inventoryBulkSpec() });
      await queryClient.invalidateQueries({ queryKey: queryKeys.inventoryProjection() });
    },
  }));
}
