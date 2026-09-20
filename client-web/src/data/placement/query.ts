import { createQuery } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import { getPlacedLedger } from "./request";

export function usePlacedLedgerQuery() {
  return createQuery(() => ({
    queryKey: queryKeys.placedLedger(),
    queryFn: getPlacedLedger,
    // A placement tick (data/placement/mutation.ts) marks this stale rather
    // than refetching it, so it is stale for the whole sorting session by
    // design — refetching on window focus would pay a full projection refold
    // and rebuild the open location's rows on every alt-tab back to the page
    // (#105). It reconciles on the next mount instead.
    refetchOnWindowFocus: false,
  }));
}
