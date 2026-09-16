import { describe, expect, it } from "vitest";
import { parseDeckstatsCsv } from "./import_deckstats";
import { DECKSTATS_FIXTURE_CSV } from "./import_deckstats.fixture";

function keyOf(row: {
  setCode: string;
  collectorNumber: string;
  finish: string;
  language: string;
}) {
  return `${row.setCode} ${row.collectorNumber} ${row.finish} ${row.language}`;
}

describe("parseDeckstatsCsv", () => {
  it("locates columns by name and keeps different languages of the same printing separate", () => {
    const result = parseDeckstatsCsv(DECKSTATS_FIXTURE_CSV);
    expect(result.error).toBeNull();

    const byKey = new Map(result.rows.map((row) => [keyOf(row), row]));

    // M19/85 and M15/85 each appear as a de row and an en row: distinct
    // kinds of copy (ADR 0010), not summed together.
    expect(byKey.get("M19 85 nonfoil de")?.quantity).toBe(1);
    expect(byKey.get("M19 85 nonfoil en")?.quantity).toBe(2);
    expect(byKey.get("M15 85 nonfoil de")?.quantity).toBe(2);
    expect(byKey.get("M15 85 nonfoil en")?.quantity).toBe(2);

    // Same card name, different collector numbers stay distinct.
    expect(byKey.get("MH2 354 nonfoil en")?.quantity).toBe(1);
    expect(byKey.get("MH2 147 nonfoil en")?.quantity).toBe(3);
  });

  it("sums quantities for rows sharing the exact same printing, finish, and language", () => {
    const csv = "amount,set_code,collector_number,is_foil,language\n2,ISD,85,,en\n3,ISD,85,,en\n";
    const result = parseDeckstatsCsv(csv);
    expect(result.rows).toEqual([
      { setCode: "ISD", collectorNumber: "85", finish: "nonfoil", language: "en", quantity: 5 },
    ]);
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
    expect(result.rows[0]).toEqual({
      setCode: "ISD",
      collectorNumber: "85",
      finish: "nonfoil",
      language: "de",
      quantity: 1,
    });
    expect(result.rows[1]).toEqual({
      setCode: "MH2",
      collectorNumber: "1",
      finish: "nonfoil",
      language: "en",
      quantity: 2,
    });
  });

  it("errors when a required column is missing", () => {
    const result = parseDeckstatsCsv("amount,set_code\n1,ISD");
    expect(result.rows).toEqual([]);
    expect(result.error).toContain("Missing required column");
  });

  it("errors when is_foil or language columns are absent", () => {
    const result = parseDeckstatsCsv("amount,set_code,collector_number\n1,ISD,85");
    expect(result.rows).toEqual([]);
    expect(result.error).toContain("Missing required column");
  });

  it("skips rows with a non-positive amount without rejecting them", () => {
    const csv = "amount,set_code,collector_number,is_foil,language\n0,ISD,85,,en\n2,ISD,86,,en\n";
    const result = parseDeckstatsCsv(csv);
    expect(result.rows).toEqual([
      { setCode: "ISD", collectorNumber: "86", finish: "nonfoil", language: "en", quantity: 2 },
    ]);
    expect(result.rejected).toEqual([]);
  });

  it("tolerates a reordered header", () => {
    const csv = "collector_number,language,set_code,is_foil,amount\n85,en,ISD,,3\n";
    const result = parseDeckstatsCsv(csv);
    expect(result.rows).toEqual([
      { setCode: "ISD", collectorNumber: "85", finish: "nonfoil", language: "en", quantity: 3 },
    ]);
  });

  it("maps is_foil=1 to foil and rejects unrecognized values", () => {
    const csv =
      "amount,set_code,collector_number,is_foil,language\n" + "1,ISD,85,1,en\n" + "1,ISD,86,2,en\n";
    const result = parseDeckstatsCsv(csv);
    expect(result.rows).toEqual([
      { setCode: "ISD", collectorNumber: "85", finish: "foil", language: "en", quantity: 1 },
    ]);
    expect(result.rejected).toHaveLength(1);
    expect(result.rejected[0]?.reason).toContain("Unrecognized is_foil value");
  });

  it("maps known two-letter language codes and rejects unmappable ones", () => {
    const csv =
      "amount,set_code,collector_number,is_foil,language\n" + "1,ISD,85,,ru\n" + "1,ISD,86,,zhs\n";
    const result = parseDeckstatsCsv(csv);
    expect(result.rows).toEqual([
      { setCode: "ISD", collectorNumber: "85", finish: "nonfoil", language: "ru", quantity: 1 },
    ]);
    expect(result.rejected).toHaveLength(1);
    expect(result.rejected[0]?.reason).toContain("Unrecognized language");
  });
});
