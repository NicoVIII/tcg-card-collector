import { requestJson } from "../http/request";

export type ImportCollectionPayload = {
  importRunId: string;
  sourceName: string;
  sourceChecksum: string;
  rowCount: number;
};

export type ImportStatus = {
  import_run_id: string;
  status: string;
  row_count: number;
  source_name: string;
};

export async function postImportCollection(
  payload: ImportCollectionPayload,
): Promise<{ accepted: boolean }> {
  return requestJson<{ accepted: boolean }>("/api/import", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(payload),
  });
}

export async function getLatestImportStatus(): Promise<ImportStatus> {
  return requestJson<ImportStatus>("/api/import/latest");
}
