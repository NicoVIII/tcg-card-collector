import { requestJson } from "../http/request";

export type AppSettings = {
  default_sort: string;
  default_grouping: string;
};

const DEFAULT_SETTINGS: AppSettings = {
  default_sort: "card_name",
  default_grouping: "location",
};

function asString(value: unknown, fallback = ""): string {
  return typeof value === "string" ? value : fallback;
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (typeof value !== "object" || value === null) {
    return null;
  }

  return value as Record<string, unknown>;
}

export function normalizeSettings(payload: unknown): AppSettings {
  const data = asRecord(payload);
  if (data === null) {
    return DEFAULT_SETTINGS;
  }

  return {
    default_sort: asString(data.default_sort, DEFAULT_SETTINGS.default_sort),
    default_grouping: asString(data.default_grouping, DEFAULT_SETTINGS.default_grouping),
  };
}

export async function getSettings(): Promise<AppSettings> {
  const response = await requestJson<unknown>("/api/settings");
  return normalizeSettings(response);
}

export async function updateSettings(settings: AppSettings): Promise<{ success: boolean }> {
  const response = await requestJson<unknown>("/api/settings", {
    method: "PUT",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(settings),
  });
  const data = asRecord(response);
  return { success: Boolean(data?.success) };
}
