import { describe, expect, it } from "vitest";
import { parseDeckstatsCsv } from "./import_deckstats";
import { DECKSTATS_FIXTURE_CSV } from "./import_deckstats.fixture";
import { detectImportFormat } from "./import_rows";

describe("parseDeckstatsCsv", () => {
  it("locates columns by name and aggregates duplicate keys", () => {
    const result = parseDeckstatsCsv(DECKSTATS_FIXTURE_CSV);
    expect(result.error).toBeNull();

    const byKey = new Map(result.rows.map((row) => [`${row.setCode} ${row.collectorNumber}`, row]));

    // M19/85 appears as de(1) + en(2) -> 3; M15/85 as de(2) + en(2) -> 4.
    expect(byKey.get("M19 85")?.quantity).toBe(3);
    expect(byKey.get("M15 85")?.quantity).toBe(4);

    // Same card name, different collector numbers stay distinct.
    expect(byKey.get("MH2 354")?.quantity).toBe(1);
    expect(byKey.get("MH2 147")?.quantity).toBe(3);
  });

  it("rejects rows with an empty set_code or collector_number", () => {
    const result = parseDeckstatsCsv(DECKSTATS_FIXTURE_CSV);
    // ODY, OGW (x2), SCG, HOU, SOI all lack a collector number.
    expect(result.rejected).toHaveLength(6);
    for (const rejected of result.rejected) {
      expect(rejected.reason).toContain("Missing set_code or collector_number");
    }
  });

  it("does not aggregate rejected rows into the output", () => {
    const result = parseDeckstatsCsv(DECKSTATS_FIXTURE_CSV);
    const keys = result.rows.map((row) => `${row.setCode} ${row.collectorNumber}`);
    expect(keys).not.toContain("ODY ");
    expect(keys.some((key) => key.startsWith("OGW"))).toBe(false);
  });

  it("preserves first-seen order of keys", () => {
    const result = parseDeckstatsCsv(DECKSTATS_FIXTURE_CSV);
    expect(result.rows[0]).toEqual({ setCode: "ISD", collectorNumber: "85", quantity: 1 });
    expect(result.rows[1]).toEqual({ setCode: "MH2", collectorNumber: "1", quantity: 2 });
  });

  it("errors when a required column is missing", () => {
    const result = parseDeckstatsCsv("amount,set_code\n1,ISD");
    expect(result.rows).toEqual([]);
    expect(result.error).toContain("Missing required column");
  });

  it("skips rows with a non-positive amount without rejecting them", () => {
    const csv = "amount,set_code,collector_number\n0,ISD,85\n2,ISD,86";
    const result = parseDeckstatsCsv(csv);
    expect(result.rows).toEqual([{ setCode: "ISD", collectorNumber: "86", quantity: 2 }]);
    expect(result.rejected).toEqual([]);
  });

  it("tolerates a reordered header", () => {
    const csv = "collector_number,set_code,amount\n85,ISD,3";
    const result = parseDeckstatsCsv(csv);
    expect(result.rows).toEqual([{ setCode: "ISD", collectorNumber: "85", quantity: 3 }]);
  });
});

describe("detectImportFormat", () => {
  it("detects the deckstats header", () => {
    expect(detectImportFormat(DECKSTATS_FIXTURE_CSV)).toBe("deckstats");
  });

  it("treats bare rows as the simple format", () => {
    expect(detectImportFormat("M11,146,2\n2XM,49,1")).toBe("simple");
  });
});
