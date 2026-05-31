import { requestJson } from "../http/request";

export type ImportCollectionPayload = {
  importRunId: string;
  sourceName: string;
  sourceChecksum: string;
  rowCount: number;
};

export type ImportStatus = {
  importRunId: string;
  status: string;
  rowCount: number;
  sourceName: string;
};

export type LatestImportStatusResponse =
  | { kind: "found"; run: ImportStatus }
  | { kind: "not_found" };

type UnknownRecord = Record<string, unknown>;

function asRecord(value: unknown): UnknownRecord | null {
  if (typeof value !== "object" || value === null) {
    return null;
  }

  return value as UnknownRecord;
}

function asString(value: unknown, fallback = ""): string {
  return typeof value === "string" ? value : fallback;
}

function asNumber(value: unknown, fallback = 0): number {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

export function normalizeImportCollectionResponse(payload: unknown): { accepted: boolean } {
  const data = asRecord(payload);
  return { accepted: Boolean(data?.accepted) };
}

export function normalizeLatestImportStatusResponse(payload: unknown): LatestImportStatusResponse {
  const data = asRecord(payload);
  if (data === null) {
    return { kind: "not_found" };
  }

  const statusData = asRecord(data.data ?? data.run ?? payload);
  if (statusData === null) {
    return { kind: "not_found" };
  }

  const importRunId = asString(statusData.import_run_id ?? statusData.importRunId);
  const sourceName = asString(statusData.source_name ?? statusData.sourceName);
  const status = asString(statusData.status);
  const rowCount = asNumber(statusData.row_count ?? statusData.rowCount);

  if (importRunId.length === 0 || sourceName.length === 0 || status.length === 0) {
    return { kind: "not_found" };
  }

  return {
    kind: "found",
    run: {
      importRunId,
      sourceName,
      status,
      rowCount,
    },
  };
}

export async function postImportCollection(
  payload: ImportCollectionPayload,
): Promise<{ accepted: boolean }> {
  const response = await requestJson<unknown>("/api/import", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(payload),
  });

  return normalizeImportCollectionResponse(response);
}

export async function getLatestImportStatus(): Promise<LatestImportStatusResponse> {
  const response = await requestJson<unknown>("/api/import/latest");
  return normalizeLatestImportStatusResponse(response);
}
