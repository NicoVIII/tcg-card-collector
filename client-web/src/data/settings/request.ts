import { requestJson } from "../http/request";

export type AppSettings = {
  default_sort: string;
  default_grouping: string;
};

export async function getSettings(): Promise<AppSettings> {
  return requestJson<AppSettings>("/api/settings");
}

export async function updateSettings(settings: AppSettings): Promise<{ success: boolean }> {
  return requestJson<{ success: boolean }>("/api/settings", {
    method: "PUT",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(settings),
  });
}
