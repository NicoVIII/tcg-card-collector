import { createQuery } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import { getPlacementGuidance } from "./request";

export function usePlacementGuidanceQuery() {
  return createQuery(() => ({
    queryKey: queryKeys.placementGuidance(),
    queryFn: getPlacementGuidance,
  }));
}
