import { skirClient } from "../http/skir_rpc";
import { UpdateSettings, UpdateSettingsRequest } from "../skirout/settings/commands.js";
import {
  AppSettings as RpcAppSettings,
  GetSettings,
  GetSettingsRequest,
} from "../skirout/settings/queries.js";

export type AppSettings = {
  default_sort: string;
  default_grouping: string;
};

const DEFAULT_SETTINGS: AppSettings = {
  default_sort: "card_name",
  default_grouping: "location",
};

export function normalizeSettings(payload: unknown): AppSettings {
  if (payload instanceof RpcAppSettings) {
    return {
      default_sort: payload.defaultSort || DEFAULT_SETTINGS.default_sort,
      default_grouping: payload.defaultGrouping || DEFAULT_SETTINGS.default_grouping,
    };
  }

  if (typeof payload !== "object" || payload === null) {
    return DEFAULT_SETTINGS;
  }

  const data = payload as Record<string, unknown>;

  return {
    default_sort:
      typeof (data.default_sort ?? data.defaultSort) === "string"
        ? String(data.default_sort ?? data.defaultSort)
        : DEFAULT_SETTINGS.default_sort,
    default_grouping:
      typeof (data.default_grouping ?? data.defaultGrouping) === "string"
        ? String(data.default_grouping ?? data.defaultGrouping)
        : DEFAULT_SETTINGS.default_grouping,
  };
}

export async function getSettings(): Promise<AppSettings> {
  const response = await skirClient.invokeRemote(
    GetSettings,
    GetSettingsRequest.create({ unit: true }),
    "GET",
  );

  return normalizeSettings(response);
}

export async function updateSettings(settings: AppSettings): Promise<{ success: boolean }> {
  const response = await skirClient.invokeRemote(
    UpdateSettings,
    UpdateSettingsRequest.create({
      defaultSort: settings.default_sort,
      defaultGrouping: settings.default_grouping,
    }),
  );

  return { success: response.union.kind === "SUCCESS" };
}
