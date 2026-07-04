import { createQuery } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import { getSetCompletion } from "./request";

export function useSetCompletionQuery() {
  return createQuery(() => ({
    queryKey: queryKeys.setCompletion(),
    queryFn: getSetCompletion,
  }));
}
