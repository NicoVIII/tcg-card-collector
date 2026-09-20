import { createQuery } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import { getAppVersion } from "./request";

// The running version can't change without a page reload, so there is
// nothing to invalidate it and no point refetching it on a staleness timer.
export function useAppVersionQuery() {
  return createQuery(() => ({
    queryKey: queryKeys.appVersion(),
    queryFn: getAppVersion,
    staleTime: Infinity,
  }));
}
