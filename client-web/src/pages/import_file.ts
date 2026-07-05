import { parseDeckstatsCsv } from "./import_deckstats";
import { type ImportRow, detectImportFormat, parseImportRowsCsv } from "./import_rows";

export type ParsedImportFile = {
  rows: ImportRow[];
  error: string | null;
  note: string | null;
};

// Parses an uploaded import file, auto-detecting the format, returning
// normalized rows plus a human-readable note about anything skipped
// (deckstats rejected lines).
export function parseImportFileText(text: string): ParsedImportFile {
  const format = detectImportFormat(text);
  if (format === "deckstats") {
    const result = parseDeckstatsCsv(text);
    const note =
      result.rejected.length > 0
        ? `${result.rejected.length} line(s) skipped (missing set code or collector number).`
        : null;
    return { rows: result.rows, error: result.error, note };
  }
  const result = parseImportRowsCsv(text);
  return { rows: result.rows, error: result.error, note: null };
}
