import type { QueryClient } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";

// Every mutation that can shrink the collection (a full replace or a
// decrement, unlike AddCards which only ever grows it) invalidates the same
// four queries: the collection itself, set completion, the inventory
// projection, and the placed ledger — a replace or removal can shrink the
// ledger below what's now owned (ADR 0011's reconciliation), which an add
// never does.
export async function invalidateCollectionDependents(queryClient: QueryClient) {
  await queryClient.invalidateQueries({ queryKey: queryKeys.collection() });
  await queryClient.invalidateQueries({ queryKey: queryKeys.setCompletion() });
  await queryClient.invalidateQueries({ queryKey: queryKeys.inventoryProjection() });
  await queryClient.invalidateQueries({ queryKey: queryKeys.placedLedger() });
}
