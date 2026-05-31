import { QueryClient } from "@tanstack/solid-query";

export const queryClient = new QueryClient();

export const queryKeys = {
  importStatus: ["import", "status"] as const,
  catalogList: ["catalog", "list"] as const,
  inventoryProjection: ["inventory", "projection"] as const,
  settings: ["settings"] as const,
};
