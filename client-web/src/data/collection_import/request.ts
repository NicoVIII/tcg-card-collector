import { z } from "zod";
import { httpStatusFromError } from "../http/error";
import { skirClient } from "../http/skir_rpc";
import { ImportCollection, ImportCollectionRequest } from "../skirout/collection/commands.js";
import {
  GetLatestImportStatus,
  GetLatestImportStatusRequest,
} from "../skirout/collection/queries.js";

const ImportCollectionResponseSchema = z.object({
  union: z.object({ kind: z.enum(["ACCEPTED", "REJECTED", "UNKNOWN"]) }),
});

export type ImportCollectionPayload = {
  importRunId: string;
  sourceName: string;
  rowCount: number;
  rows: Array<{
    setCode: string;
    collectorNumber: string;
    quantity: number;
  }>;
  mode: "full" | "delta";
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

export async function postImportCollection(
  payload: ImportCollectionPayload,
): Promise<{ accepted: boolean }> {
  const response = await skirClient.invokeRemote(
    ImportCollection,
    ImportCollectionRequest.create({
      importRunId: payload.importRunId,
      sourceName: payload.sourceName,
      rowCount: payload.rowCount,
      rows: payload.rows,
      mode: payload.mode === "delta" ? "DELTA" : "FULL",
    }),
  );

  const validated = ImportCollectionResponseSchema.parse(response);
  return { accepted: validated.union.kind === "ACCEPTED" };
}

export async function getLatestImportStatus(): Promise<LatestImportStatusResponse> {
  try {
    const response = await skirClient.invokeRemote(
      GetLatestImportStatus,
      GetLatestImportStatusRequest.create({ unit: true }),
      "POST",
    );

    return {
      kind: "found",
      run: {
        importRunId: response.importRunId,
        sourceName: response.sourceName,
        status: response.status,
        rowCount: response.rowCount,
      },
    };
  } catch (error) {
    if (httpStatusFromError(error) === 404) {
      return { kind: "not_found" };
    }

    throw error;
  }
}
