import { describe, expect, it } from "vitest";
import { parseImportRowsCsv } from "./import_rows";

describe("parseImportRowsCsv", () => {
  it("parses valid CSV rows", () => {
    const result = parseImportRowsCsv("Lightning Bolt,M11,146,2\nCounterspell,2XM,49,1");

    expect(result).toEqual({
      error: null,
      rows: [
        {
          cardName: "Lightning Bolt",
          setCode: "M11",
          collectorNumber: "146",
          quantity: 2,
        },
        {
          cardName: "Counterspell",
          setCode: "2XM",
          collectorNumber: "49",
          quantity: 1,
        },
      ],
    });
  });

  it("rejects invalid row shape", () => {
    const result = parseImportRowsCsv("Lightning Bolt,M11,146");
    expect(result.error).toContain("Invalid row format");
    expect(result.rows).toEqual([]);
  });

  it("rejects invalid quantity", () => {
    const result = parseImportRowsCsv("Lightning Bolt,M11,146,0");
    expect(result.error).toContain("Invalid quantity");
    expect(result.rows).toEqual([]);
  });
});
