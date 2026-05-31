import { createQuery } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import { getInventoryProjection, listInventoryRules } from "./request";

export function useInventoryRulesQuery() {
  return createQuery(() => ({
    queryKey: queryKeys.inventoryRules(),
    queryFn: listInventoryRules,
  }));
}

export function useInventoryProjectionQuery(sortBy: () => string, groupBy: () => string) {
  return createQuery(() => ({
    queryKey: queryKeys.inventoryProjection(sortBy(), groupBy()),
    queryFn: () => getInventoryProjection(sortBy(), groupBy()),
  }));
}
