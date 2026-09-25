import { skirClient } from "../http/skir_rpc";
import { ImportData, ImportDataRequest } from "../skirout/portability/commands.js";
import {
  ExportData,
  ExportDataRequest,
  PreviewImport,
  PreviewImportRequest,
} from "../skirout/portability/queries.js";

export type ExportFile = {
  filename: string;
  content: string;
};

export async function fetchExportData(): Promise<ExportFile> {
  const response = await skirClient.invokeRemote(
    ExportData,
    ExportDataRequest.create({ unit: true }),
    "POST",
  );

  return { filename: response.filename, content: response.content };
}

export type RejectedEntry = {
  position: number;
  identity: string;
  reason: string;
};

export type ImportPreview = {
  entryCount: number;
  rejected: RejectedEntry[];
};

export async function previewImport(content: string): Promise<ImportPreview> {
  const response = await skirClient.invokeRemote(
    PreviewImport,
    PreviewImportRequest.create({ content }),
    "POST",
  );

  return {
    entryCount: response.entryCount,
    rejected: response.rejected.map((entry) => ({
      position: entry.position,
      identity: entry.identity,
      reason: entry.reason,
    })),
  };
}

export async function importData(content: string): Promise<{ entryCount: number }> {
  const response = await skirClient.invokeRemote(
    ImportData,
    ImportDataRequest.create({ content }),
    "POST",
  );

  return { entryCount: response.entryCount };
}
