import { createQuery, useQueryClient } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import { listManagedLocations } from "./request";

export function useManagedLocationsQuery() {
  return createQuery(() => ({
    queryKey: queryKeys.managedLocations(),
    queryFn: listManagedLocations,
  }));
}

// A fresh read for a check made at the moment of acting (staging a
// removal), the same posture as useFetchOwnedCopies.
export function useFetchManagedLocations() {
  const queryClient = useQueryClient();

  return () =>
    queryClient.fetchQuery({
      queryKey: queryKeys.managedLocations(),
      queryFn: listManagedLocations,
      staleTime: 0,
    });
}
