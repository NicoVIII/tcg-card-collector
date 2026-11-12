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

// Where a pruned copy sat, by name: a restore assigns decks fresh ids.
export type PlacedIn = { kind: "cascade" | "managed"; name: string };

// A placed-ledger row ReconcilePlacedLedger prunes right after import (ADR
// 0011): `quantity` copies leave `location`'s ledger.
export type LedgerPrune = {
  identity: string;
  location: PlacedIn;
  quantity: number;
};

// Structural, so it covers both the queries and the commands contract's copy
// of PlacedIn.
type WireLedgerPrune = {
  identity: string;
  location: {
    union:
      | { kind: "UNKNOWN"; value: undefined }
      | { kind: "cascade"; value: string }
      | { kind: "managed"; value: string };
  };
  quantity: number;
};

function fromWireLedgerPrune(entry: WireLedgerPrune): LedgerPrune {
  const location = entry.location.union;
  if (location.kind === "UNKNOWN") {
    throw new Error("The server sent a location of an unknown kind.");
  }
  return {
    identity: entry.identity,
    location: { kind: location.kind, name: location.value },
    quantity: entry.quantity,
  };
}

// A deck member the imported collection can't supply — the shortfall the
// deck will show right after import (ADR 0022).
export type DeckShortfall = {
  location_name: string;
  identity: string;
  missing: number;
};

export type ImportPreview = {
  sections: SectionCount[];
  rejected: RejectedEntry[];
  pruned: LedgerPrune[];
  shortfall: DeckShortfall[];
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
    pruned: response.pruned.map(fromWireLedgerPrune),
    shortfall: response.shortfall.map((entry) => ({
      location_name: entry.locationName,
      identity: entry.identity,
      missing: entry.missing,
    })),
  };
}

export type ImportedData = {
  sections: SectionCount[];
  pruned: LedgerPrune[];
};

export async function importData(content: string): Promise<ImportedData> {
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
    pruned: response.pruned.map(fromWireLedgerPrune),
  };
}
