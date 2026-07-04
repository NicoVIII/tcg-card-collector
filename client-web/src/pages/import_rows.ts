export type ImportRow = {
  setCode: string;
  collectorNumber: string;
  quantity: number;
};

export type ImportFormat = "simple" | "deckstats";

// Autodetects the paste format: a deckstats export leads with a header naming
// its columns; the bespoke format is bare `set_code,collector_number,quantity`
// rows with no such header. Falls back to "simple" when unsure.
export function detectImportFormat(text: string): ImportFormat {
  const firstLine =
    text
      .split("\n")
      .map((line) => line.trim())
      .find((line) => line.length > 0) ?? "";
  const lower = firstLine.toLowerCase();
  const looksLikeDeckstatsHeader =
    lower.includes("amount") && lower.includes("set_code") && lower.includes("collector_number");
  return looksLikeDeckstatsHeader ? "deckstats" : "simple";
}

export function parseImportRowsCsv(rowsCsv: string): {
  rows: ImportRow[];
  error: string | null;
} {
  const lines = rowsCsv
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.length > 0);

  const rows: ImportRow[] = [];

  for (const line of lines) {
    const [setCodeRaw, collectorNumberRaw, quantityRaw] = line
      .split(",")
      .map((part) => part.trim());

    if (!setCodeRaw || !collectorNumberRaw || !quantityRaw) {
      return { rows: [], error: `Invalid row format: ${line}` };
    }

    const quantity = Number.parseInt(quantityRaw, 10);
    if (!Number.isFinite(quantity) || quantity <= 0) {
      return { rows: [], error: `Invalid quantity in row: ${line}` };
    }

    rows.push({
      setCode: setCodeRaw,
      collectorNumber: collectorNumberRaw,
      quantity,
    });
  }

  return { rows, error: null };
}
