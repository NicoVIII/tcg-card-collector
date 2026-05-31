import { createMutation, useQueryClient } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import { updateSettings, type AppSettings } from "./request";

export function useUpdateSettingsMutation() {
  const queryClient = useQueryClient();

  return createMutation(() => ({
    mutationFn: (settings: AppSettings) => updateSettings(settings),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: queryKeys.settings() });
    },
  }));
}
