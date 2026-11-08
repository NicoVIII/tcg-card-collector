import { createQuery } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import { listManagedLocations } from "./request";

export function useManagedLocationsQuery() {
  return createQuery(() => ({
    queryKey: queryKeys.managedLocations(),
    queryFn: listManagedLocations,
  }));
}
