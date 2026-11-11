import { createQuery } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import { listLocationAudits } from "./request";

export function useLocationAuditsQuery() {
  return createQuery(() => ({
    queryKey: queryKeys.locationAudits(),
    queryFn: listLocationAudits,
  }));
}
