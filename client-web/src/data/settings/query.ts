import { createQuery } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import { getSettings } from "./request";

export function useSettingsQuery() {
  return createQuery(() => ({
    queryKey: queryKeys.settings(),
    queryFn: getSettings,
  }));
}
