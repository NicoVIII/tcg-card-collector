import { createQuery } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import { getPlacedLedger } from "./request";

export function usePlacedLedgerQuery() {
  return createQuery(() => ({
    queryKey: queryKeys.placedLedger(),
    queryFn: getPlacedLedger,
  }));
}
