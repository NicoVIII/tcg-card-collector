import { createQuery } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import { getLatestImportStatus } from "./request";

export function useLatestImportStatusQuery(refetchIntervalMs?: () => number | false) {
  return createQuery(() => ({
    queryKey: queryKeys.importStatus(),
    queryFn: getLatestImportStatus,
    refetchInterval: refetchIntervalMs?.() ?? false,
  }));
}
