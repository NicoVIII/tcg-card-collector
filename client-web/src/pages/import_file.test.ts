import { describe, expect, it } from "vitest";
import { parseImportFileText } from "./import_file";

const deckstatsCsv = [
  "amount,set_code,collector_number,name",
  "2,blb,123,Some Card",
  "1,blb,124,Other Card",
].join("\n");

describe("parseImportFileText", () => {
  it("auto-detects a deckstats export by its header", () => {
    const result = parseImportFileText(deckstatsCsv);
    expect(result.error).toBeNull();
    expect(result.rows).toEqual([
      { setCode: "blb", collectorNumber: "123", quantity: 2 },
      { setCode: "blb", collectorNumber: "124", quantity: 1 },
    ]);
  });

  it("notes skipped deckstats lines", () => {
    const withBadLine = `${deckstatsCsv}\n3,,125,No Set Code`;
    const result = parseImportFileText(withBadLine);
    expect(result.rows).toHaveLength(2);
    expect(result.note).toContain("1 line(s) skipped");
  });

  it("falls back to the simple format without a header", () => {
    const result = parseImportFileText("m11,146,2");
    expect(result.error).toBeNull();
    expect(result.rows).toEqual([{ setCode: "m11", collectorNumber: "146", quantity: 2 }]);
    expect(result.note).toBeNull();
  });

  it("surfaces parse errors", () => {
    const result = parseImportFileText("not,a,valid,row,at,all");
    expect(result.error).not.toBeNull();
  });
});
