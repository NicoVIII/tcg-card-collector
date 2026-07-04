import { createQuery } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import { getBulkSpec, getInventoryProjection, listInventoryRules } from "./request";

export function useInventoryRulesQuery() {
  return createQuery(() => ({
    queryKey: queryKeys.inventoryRules(),
    queryFn: listInventoryRules,
  }));
}

export function useBulkSpecQuery() {
  return createQuery(() => ({
    queryKey: queryKeys.inventoryBulkSpec(),
    queryFn: getBulkSpec,
  }));
}

export function useInventoryProjectionQuery() {
  return createQuery(() => ({
    queryKey: queryKeys.inventoryProjection(),
    queryFn: getInventoryProjection,
  }));
}
