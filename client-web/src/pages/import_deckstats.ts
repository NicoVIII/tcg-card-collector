export type ImportRow = {
  setCode: string;
  collectorNumber: string;
  quantity: number;
};

// Parses a deckstats.net collection CSV export into normalized import rows.
//
// deckstats exports many columns (foil, language, condition, comment, ...) in an
// order that can drift, so we locate the three columns we care about by *name*
// from the header (amount, set_code, collector_number) rather than by position.
// Finish/language/condition are intentionally dropped: the collection is keyed
// only by (set_code, collector_number), so we collapse duplicate physical
// printings by summing their quantities per key.

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

const REQUIRED_COLUMNS = ["amount", "set_code", "collector_number"] as const;

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

function parseDataLine(entry: NumberedLine, columns: Record<string, number>): LineOutcome {
  const fields = parseCsvLine(entry.content);
  const amountRaw = (fields[columns.amount] ?? "").trim();
  const setCode = (fields[columns.set_code] ?? "").trim();
  const collectorNumber = (fields[columns.collector_number] ?? "").trim();

  const amount = Number.parseInt(amountRaw, 10);
  if (!Number.isFinite(amount)) {
    return rejectLine(entry, `Invalid amount "${amountRaw}".`);
  }
  if (amount <= 0) {
    // Not an error, just nothing to import.
    return { kind: "skipped" };
  }
  if (setCode.length === 0 || collectorNumber.length === 0) {
    return rejectLine(entry, "Missing set_code or collector_number.");
  }
  return { kind: "row", row: { setCode, collectorNumber, quantity: amount } };
}

// A Map keeps first-seen key order, and re-setting an existing key does not move it.
function sumQuantitiesPerKey(rows: ImportRow[]): ImportRow[] {
  const byKey = new Map<string, ImportRow>();
  for (const row of rows) {
    const key = `${row.setCode}/${row.collectorNumber}`;
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
        "Missing required column(s). Expected a header with amount, set_code, and collector_number.",
    };
  }

  const outcomes = numberedLines.slice(1).map((entry) => parseDataLine(entry, columns));
  const rows = outcomes.flatMap((outcome) => (outcome.kind === "row" ? [outcome.row] : []));
  const rejected = outcomes.flatMap((outcome) =>
    outcome.kind === "rejected" ? [outcome.rejected] : [],
  );

  return { rows: sumQuantitiesPerKey(rows), rejected, error: null };
}
