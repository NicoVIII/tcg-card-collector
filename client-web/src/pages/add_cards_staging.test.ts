import { describe, expect, it } from "vitest";
import {
  addEntry,
  normalizeEntry,
  removeEntry,
  toAddCardsRows,
  totalCards,
} from "./add_cards_staging";

describe("normalizeEntry", () => {
  it("trims and lowercases the set code and trims the collector number", () => {
    expect(normalizeEntry({ setCode: " BLB ", collectorNumber: " 123 ", quantity: 1 })).toEqual({
      setCode: "blb",
      collectorNumber: "123",
      quantity: 1,
    });
  });

  it("rejects blank set code or collector number", () => {
    expect(normalizeEntry({ setCode: "  ", collectorNumber: "1", quantity: 1 })).toBeNull();
    expect(normalizeEntry({ setCode: "blb", collectorNumber: "", quantity: 1 })).toBeNull();
  });

  it("rejects non-positive and non-integer quantities", () => {
    expect(normalizeEntry({ setCode: "blb", collectorNumber: "1", quantity: 0 })).toBeNull();
    expect(normalizeEntry({ setCode: "blb", collectorNumber: "1", quantity: 1.5 })).toBeNull();
    expect(
      normalizeEntry({ setCode: "blb", collectorNumber: "1", quantity: Number.NaN }),
    ).toBeNull();
  });
});

describe("addEntry", () => {
  it("appends a new card at the end", () => {
    const list = addEntry([], { setCode: "blb", collectorNumber: "1", quantity: 2 });
    expect(addEntry(list, { setCode: "blb", collectorNumber: "2", quantity: 1 })).toEqual([
      { setCode: "blb", collectorNumber: "1", quantity: 2 },
      { setCode: "blb", collectorNumber: "2", quantity: 1 },
    ]);
  });

  it("sums quantities when the card is already staged", () => {
    const list = addEntry([], { setCode: "blb", collectorNumber: "1", quantity: 2 });
    expect(addEntry(list, { setCode: "blb", collectorNumber: "1", quantity: 3 })).toEqual([
      { setCode: "blb", collectorNumber: "1", quantity: 5 },
    ]);
  });
});

describe("removeEntry", () => {
  it("removes exactly the matching card", () => {
    const list = [
      { setCode: "blb", collectorNumber: "1", quantity: 2 },
      { setCode: "blb", collectorNumber: "2", quantity: 1 },
    ];
    expect(removeEntry(list, list[0])).toEqual([
      { setCode: "blb", collectorNumber: "2", quantity: 1 },
    ]);
  });
});

describe("totalCards", () => {
  it("sums the staged quantities", () => {
    expect(
      totalCards([
        { setCode: "blb", collectorNumber: "1", quantity: 2 },
        { setCode: "blb", collectorNumber: "2", quantity: 3 },
      ]),
    ).toBe(5);
  });
});

describe("toAddCardsRows", () => {
  it("maps staged entries to payload rows", () => {
    expect(toAddCardsRows([{ setCode: "blb", collectorNumber: "1", quantity: 2 }])).toEqual([
      { setCode: "blb", collectorNumber: "1", quantity: 2 },
    ]);
  });
});
