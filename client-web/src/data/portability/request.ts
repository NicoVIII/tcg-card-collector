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

// How many valid entries a section will write (preview) or did write
// (import result) — only present for a section the file actually had
// (#119: an older export, or a section this build doesn't recognise, is
// left untouched rather than shown with a zero count).
export type SectionCount = {
  section: string;
  count: number;
};

export type RejectedEntry = {
  section: string;
  position: number;
  identity: string;
  reason: string;
};

// A placed-ledger copy the imported collection doesn't own enough of —
// what ReconcilePlacedLedger will prune right after import (ADR 0011).
export type LedgerExcess = {
  identity: string;
  placed: number;
  owned: number;
};

export type ImportPreview = {
  sections: SectionCount[];
  rejected: RejectedEntry[];
  excess: LedgerExcess[];
};

export async function previewImport(content: string): Promise<ImportPreview> {
  const response = await skirClient.invokeRemote(
    PreviewImport,
    PreviewImportRequest.create({ content }),
    "POST",
  );

  return {
    sections: response.sections.map((section) => ({
      section: section.section,
      count: section.count,
    })),
    rejected: response.rejected.map((entry) => ({
      section: entry.section,
      position: entry.position,
      identity: entry.identity,
      reason: entry.reason,
    })),
    excess: response.excess.map((entry) => ({
      identity: entry.identity,
      placed: entry.placed,
      owned: entry.owned,
    })),
  };
}

export async function importData(content: string): Promise<{ sections: SectionCount[] }> {
  const response = await skirClient.invokeRemote(
    ImportData,
    ImportDataRequest.create({ content }),
    "POST",
  );

  return {
    sections: response.sections.map((section) => ({
      section: section.section,
      count: section.count,
    })),
  };
}
