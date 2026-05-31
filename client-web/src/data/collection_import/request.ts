import { skirClient } from "../http/skir_rpc";
import {
  ImportCollection,
  ImportCollectionRequest,
} from "../skirout/collection_import/commands.js";
import {
  GetLatestImportStatus,
  GetLatestImportStatusRequest,
  ImportStatus as RpcImportStatus,
} from "../skirout/collection_import/queries.js";

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

export function normalizeImportCollectionResponse(payload: unknown): { accepted: boolean } {
  if (
    typeof payload === "object" &&
    payload !== null &&
    "union" in payload &&
    typeof (payload as { union?: { kind?: unknown } }).union?.kind === "string"
  ) {
    return { accepted: (payload as { union: { kind: string } }).union.kind === "ACCEPTED" };
  }

  const data = payload as { accepted?: unknown } | null;
  return { accepted: Boolean(data?.accepted) };
}

export function normalizeLatestImportStatusResponse(payload: unknown): LatestImportStatusResponse {
  if (payload instanceof RpcImportStatus) {
    return {
      kind: "found",
      run: {
        importRunId: payload.importRunId,
        sourceName: payload.sourceName,
        status: payload.status,
        rowCount: payload.rowCount,
      },
    };
  }

  const data = payload as Record<string, unknown> | null;
  if (data === null || typeof data !== "object") {
    return { kind: "not_found" };
  }

  const statusData = (data.data ?? data.run ?? payload) as Record<string, unknown> | null;
  if (statusData === null || typeof statusData !== "object") {
    return { kind: "not_found" };
  }

  const importRunId =
    typeof (statusData.import_run_id ?? statusData.importRunId) === "string"
      ? String(statusData.import_run_id ?? statusData.importRunId)
      : "";
  const sourceName =
    typeof (statusData.source_name ?? statusData.sourceName) === "string"
      ? String(statusData.source_name ?? statusData.sourceName)
      : "";
  const status = typeof statusData.status === "string" ? statusData.status : "";
  const rowCount =
    typeof (statusData.row_count ?? statusData.rowCount) === "number"
      ? Number(statusData.row_count ?? statusData.rowCount)
      : 0;

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
  const response = await skirClient.invokeRemote(
    ImportCollection,
    ImportCollectionRequest.create({
      importRunId: payload.importRunId,
      sourceName: payload.sourceName,
      sourceChecksum: payload.sourceChecksum,
      rowCount: payload.rowCount,
    }),
  );

  return normalizeImportCollectionResponse(response);
}

export async function getLatestImportStatus(): Promise<LatestImportStatusResponse> {
  try {
    const response = await skirClient.invokeRemote(
      GetLatestImportStatus,
      GetLatestImportStatusRequest.create({ unit: true }),
      "GET",
    );

    return normalizeLatestImportStatusResponse(response);
  } catch (error) {
    if (error instanceof Error && error.message.startsWith("HTTP status 404")) {
      return { kind: "not_found" };
    }

    throw error;
  }
}
