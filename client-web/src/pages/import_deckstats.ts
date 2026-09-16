import type { Finish, Language } from "../data/collection/copy_kind";

export type ImportRow = {
  setCode: string;
  collectorNumber: string;
  finish: Finish;
  language: Language;
  quantity: number;
};

// deckstats exports many columns (foil, language, condition, comment, ...) in an
// order that can drift, so we locate the columns we care about by *name* from
// the header rather than by position. Finish and language are now part of the
// collection's identity (ADR 0010: two copies differing in either are distinct
// entries), so they're required columns, not dropped.

export type RejectedLine = {
  lineNumber: number;
  content: string;
  reason: string;
};

export type DeckstatsParseResult = {
  rows: ImportRow[];
  rejected: RejectedLine[];
  // Fatal, whole-file problem (e.g. a required column is absent). When set,
  // rows/rejected are empty and the import cannot proceed.
  error: string | null;
};

const REQUIRED_COLUMNS = ["amount", "set_code", "collector_number", "is_foil", "language"] as const;

// deckstats' own two-letter codes that coincide with Scryfall's are mapped
// directly. Chinese isn't: deckstats has no zhs/zht split, so it's rejected
// rather than guessed. Widen this list once a real export shows other codes.
const DECKSTATS_LANGUAGE_CODES: readonly Language[] = [
  "en",
  "es",
  "fr",
  "de",
  "it",
  "pt",
  "ja",
  "ko",
  "ru",
  "he",
  "la",
  "ar",
];

// deckstats' is_foil column is blank for nonfoil, "1" for foil. It can't tell
// etched from foil, so an etched card imports as foil until corrected by hand
// (ADR 0010's known limitation of this importer).
function mapFinish(raw: string): Finish | null {
  const trimmed = raw.trim();
  if (trimmed === "") {
    return "nonfoil";
  }
  if (trimmed === "1") {
    return "foil";
  }
  return null;
}

function mapLanguage(raw: string): Language | null {
  const trimmed = raw.trim().toLowerCase();
  return (DECKSTATS_LANGUAGE_CODES as readonly string[]).includes(trimmed)
    ? (trimmed as Language)
    : null;
}

// Splits a single CSV line into fields, honoring double-quoted fields and
// escaped quotes (""). Assumes fields do not contain embedded newlines, which
// holds for deckstats collection exports.
function parseCsvLine(line: string): string[] {
  const fields: string[] = [];
  let current = "";
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    if (inQuotes) {
      if (char === '"') {
        if (line[i + 1] === '"') {
          current += '"';
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        current += char;
      }
    } else if (char === '"') {
      inQuotes = true;
    } else if (char === ",") {
      fields.push(current);
      current = "";
    } else {
      current += char;
    }
  }
  fields.push(current);
  return fields;
}

function locateColumns(header: string[]): Record<string, number> | null {
  const normalized = header.map((name) => name.trim().toLowerCase());
  const indices: Record<string, number> = {};
  for (const column of REQUIRED_COLUMNS) {
    const index = normalized.indexOf(column);
    if (index === -1) {
      return null;
    }
    indices[column] = index;
  }
  return indices;
}

type NumberedLine = {
  lineNumber: number;
  content: string;
};

type LineOutcome =
  | { kind: "row"; row: ImportRow }
  | { kind: "rejected"; rejected: RejectedLine }
  | { kind: "skipped" };

// Keeps the original 1-based line number for the rejected-line report while
// skipping blank lines.
function numberNonBlankLines(csv: string): NumberedLine[] {
  return csv
    .split("\n")
    .map((content, index) => ({ lineNumber: index + 1, content }))
    .filter((entry) => entry.content.trim().length > 0);
}

function rejectLine(entry: NumberedLine, reason: string): LineOutcome {
  return { kind: "rejected", rejected: { ...entry, reason } };
}

type CopyKindResult =
  | { ok: true; finish: Finish; language: Language }
  | { ok: false; outcome: LineOutcome };

// Resolves the finish/language columns, or the rejection to report if either
// doesn't map — folded into one result so the caller has a single check.
function copyKindOrReject(
  entry: NumberedLine,
  isFoilRaw: string,
  languageRaw: string,
): CopyKindResult {
  const finish = mapFinish(isFoilRaw);
  if (finish === null) {
    return { ok: false, outcome: rejectLine(entry, `Unrecognized is_foil value "${isFoilRaw}".`) };
  }
  const language = mapLanguage(languageRaw);
  if (language === null) {
    return { ok: false, outcome: rejectLine(entry, `Unrecognized language "${languageRaw}".`) };
  }
  return { ok: true, finish, language };
}

type AmountResult =
  | { kind: "value"; amount: number }
  | { kind: "reject"; outcome: LineOutcome }
  | { kind: "skip" };

function parseAmount(entry: NumberedLine, raw: string): AmountResult {
  const amount = Number.parseInt(raw, 10);
  if (!Number.isFinite(amount)) {
    return { kind: "reject", outcome: rejectLine(entry, `Invalid amount "${raw}".`) };
  }
  if (amount <= 0) {
    // Not an error, just nothing to import.
    return { kind: "skip" };
  }
  return { kind: "value", amount };
}

function fieldAt(fields: string[], columns: Record<string, number>, name: string): string {
  return fields[columns[name]] ?? "";
}

function parseDataLine(entry: NumberedLine, columns: Record<string, number>): LineOutcome {
  const fields = parseCsvLine(entry.content);
  const setCode = fieldAt(fields, columns, "set_code").trim();
  const collectorNumber = fieldAt(fields, columns, "collector_number").trim();

  const amountResult = parseAmount(entry, fieldAt(fields, columns, "amount").trim());
  if (amountResult.kind === "reject") {
    return amountResult.outcome;
  }
  if (amountResult.kind === "skip") {
    return { kind: "skipped" };
  }
  if (setCode.length === 0 || collectorNumber.length === 0) {
    return rejectLine(entry, "Missing set_code or collector_number.");
  }

  const copyKind = copyKindOrReject(
    entry,
    fieldAt(fields, columns, "is_foil"),
    fieldAt(fields, columns, "language"),
  );
  if (!copyKind.ok) {
    return copyKind.outcome;
  }
  return {
    kind: "row",
    row: {
      setCode,
      collectorNumber,
      finish: copyKind.finish,
      language: copyKind.language,
      quantity: amountResult.amount,
    },
  };
}

// A Map keeps first-seen key order, and re-setting an existing key does not move it.
function sumQuantitiesPerKey(rows: ImportRow[]): ImportRow[] {
  const byKey = new Map<string, ImportRow>();
  for (const row of rows) {
    const key = `${row.setCode}/${row.collectorNumber}/${row.finish}/${row.language}`;
    const existing = byKey.get(key);
    byKey.set(
      key,
      existing === undefined ? row : { ...existing, quantity: existing.quantity + row.quantity },
    );
  }
  return [...byKey.values()];
}

export function parseDeckstatsCsv(csv: string): DeckstatsParseResult {
  const numberedLines = numberNonBlankLines(csv);

  const headerEntry = numberedLines[0];
  if (headerEntry === undefined) {
    return { rows: [], rejected: [], error: "The file is empty." };
  }

  const columns = locateColumns(parseCsvLine(headerEntry.content));
  if (columns === null) {
    return {
      rows: [],
      rejected: [],
      error:
        "Missing required column(s). Expected a header with amount, set_code, collector_number, is_foil, and language.",
    };
  }

  const outcomes = numberedLines.slice(1).map((entry) => parseDataLine(entry, columns));
  const rows = outcomes.flatMap((outcome) => (outcome.kind === "row" ? [outcome.row] : []));
  const rejected = outcomes.flatMap((outcome) =>
    outcome.kind === "rejected" ? [outcome.rejected] : [],
  );

  return { rows: sumQuantitiesPerKey(rows), rejected, error: null };
}
