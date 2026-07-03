import { skirClient } from "../http/skir_rpc";
import {
  UpdatePlanningPreferences,
  UpdatePlanningPreferencesRequest,
} from "../skirout/inventory_planning/commands.js";
import {
  GetPlanningPreferences,
  GetPlanningPreferencesRequest,
} from "../skirout/inventory_planning/queries.js";

export type AppSettings = {
  default_sort: string;
  default_grouping: string;
};

export async function getSettings(): Promise<AppSettings> {
  const response = await skirClient.invokeRemote(
    GetPlanningPreferences,
    GetPlanningPreferencesRequest.create({ unit: true }),
    "POST",
  );

  return { default_sort: response.defaultSort, default_grouping: response.defaultGrouping };
}

export async function updateSettings(settings: AppSettings): Promise<{ success: boolean }> {
  const response = await skirClient.invokeRemote(
    UpdatePlanningPreferences,
    UpdatePlanningPreferencesRequest.create({
      defaultSort: settings.default_sort,
      defaultGrouping: settings.default_grouping,
    }),
  );

  return { success: response.union.kind === "SUCCESS" };
}
