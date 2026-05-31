import { createQuery } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import { getLatestImportStatus } from "./request";

export function useLatestImportStatusQuery() {
  return createQuery(() => ({
    queryKey: queryKeys.importStatus(),
    queryFn: getLatestImportStatus,
  }));
}
