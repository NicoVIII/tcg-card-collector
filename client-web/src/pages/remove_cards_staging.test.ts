import { describe, expect, it } from "vitest";
import {
  exceedsOwned,
  refreshOwned,
  stageEntry,
  staleMessage,
  normalizeEntry,
  removeEntry,
  toRemoveCardsRows,
  totalCards,
} from "./remove_cards_staging";

const NONFOIL_EN = { finish: "nonfoil", language: "en" } as const;

describe("normalizeEntry", () => {
  it("trims and lowercases the set code and trims the collector number", () => {
    expect(
      normalizeEntry({ setCode: " BLB ", collectorNumber: " 123 ", ...NONFOIL_EN, quantity: 1 }),
    ).toEqual({
      setCode: "blb",
      collectorNumber: "123",
      ...NONFOIL_EN,
      quantity: 1,
    });
  });

  it("rejects blank set code or collector number", () => {
    expect(
      normalizeEntry({ setCode: "  ", collectorNumber: "1", ...NONFOIL_EN, quantity: 1 }),
    ).toBeNull();
    expect(
      normalizeEntry({ setCode: "blb", collectorNumber: "", ...NONFOIL_EN, quantity: 1 }),
    ).toBeNull();
  });

  it("rejects non-positive and non-integer quantities", () => {
    expect(
      normalizeEntry({ setCode: "blb", collectorNumber: "1", ...NONFOIL_EN, quantity: 0 }),
    ).toBeNull();
    expect(
      normalizeEntry({ setCode: "blb", collectorNumber: "1", ...NONFOIL_EN, quantity: 1.5 }),
    ).toBeNull();
    expect(
      normalizeEntry({
        setCode: "blb",
        collectorNumber: "1",
        ...NONFOIL_EN,
        quantity: Number.NaN,
      }),
    ).toBeNull();
  });

  it("rejects an unrecognized finish or language", () => {
    expect(
      normalizeEntry({
        setCode: "blb",
        collectorNumber: "1",
        finish: "shiny",
        language: "en",
        quantity: 1,
      }),
    ).toBeNull();
    expect(
      normalizeEntry({
        setCode: "blb",
        collectorNumber: "1",
        finish: "nonfoil",
        language: "klingon",
        quantity: 1,
      }),
    ).toBeNull();
  });

  it("accepts a non-default finish and language", () => {
    expect(
      normalizeEntry({
        setCode: "blb",
        collectorNumber: "1",
        finish: "foil",
        language: "de",
        quantity: 1,
      }),
    ).toEqual({
      setCode: "blb",
      collectorNumber: "1",
      finish: "foil",
      language: "de",
      quantity: 1,
    });
  });
});

const ENTRY = { setCode: "blb", collectorNumber: "1", ...NONFOIL_EN };
const OWNED_NONFOIL = (quantity: number) => ({ ...NONFOIL_EN, quantity });

describe("stageEntry", () => {
  it("appends a new card at the end, recording the owned quantity", () => {
    const first = stageEntry([], { ...ENTRY, quantity: 2 }, [OWNED_NONFOIL(3)]);
    expect(first).toEqual({ ok: true, list: [{ ...ENTRY, quantity: 2, owned: 3 }] });
    if (!first.ok) throw new Error("unreachable");

    expect(
      stageEntry(first.list, { ...ENTRY, collectorNumber: "2", quantity: 1 }, [OWNED_NONFOIL(1)]),
    ).toEqual({
      ok: true,
      list: [
        { ...ENTRY, quantity: 2, owned: 3 },
        { ...ENTRY, collectorNumber: "2", quantity: 1, owned: 1 },
      ],
    });
  });

  it("sums quantities when the same copy is already staged", () => {
    const staged = [{ ...ENTRY, quantity: 2, owned: 5 }];
    expect(stageEntry(staged, { ...ENTRY, quantity: 3 }, [OWNED_NONFOIL(5)])).toEqual({
      ok: true,
      list: [{ ...ENTRY, quantity: 5, owned: 5 }],
    });
  });

  it("keeps a different finish as a separate staged line", () => {
    const staged = [{ ...ENTRY, quantity: 2, owned: 2 }];
    const result = stageEntry(staged, { ...ENTRY, finish: "foil", quantity: 1 }, [
      OWNED_NONFOIL(2),
      { finish: "foil", language: "en", quantity: 1 },
    ]);
    expect(result).toEqual({
      ok: true,
      list: [
        { ...ENTRY, quantity: 2, owned: 2 },
        { ...ENTRY, finish: "foil", quantity: 1, owned: 1 },
      ],
    });
  });

  it("refuses a printing that isn't owned at all", () => {
    expect(stageEntry([], { ...ENTRY, quantity: 1 }, [])).toEqual({
      ok: false,
      message: "You don't own blb 1 (nonfoil·en).",
    });
  });

  it("refuses an owned printing in a finish or language that isn't owned, naming what is", () => {
    expect(
      stageEntry([], { ...ENTRY, quantity: 1 }, [{ finish: "foil", language: "de", quantity: 1 }]),
    ).toEqual({
      ok: false,
      message: "You don't own blb 1 (nonfoil·en); you own it as foil·de.",
    });
  });

  it("refuses a quantity above the owned one", () => {
    expect(stageEntry([], { ...ENTRY, quantity: 4 }, [OWNED_NONFOIL(3)])).toEqual({
      ok: false,
      message: "Only 3 owned.",
    });
  });

  it("counts what's already staged against the owned quantity", () => {
    const staged = [{ ...ENTRY, quantity: 2, owned: 3 }];
    expect(stageEntry(staged, { ...ENTRY, quantity: 2 }, [OWNED_NONFOIL(3)])).toEqual({
      ok: false,
      message: "Only 3 owned (2 already staged).",
    });
  });
});

describe("removeEntry", () => {
  it("removes exactly the matching card", () => {
    const list = [
      { setCode: "blb", collectorNumber: "1", ...NONFOIL_EN, quantity: 2, owned: 2 },
      { setCode: "blb", collectorNumber: "2", ...NONFOIL_EN, quantity: 1, owned: 1 },
    ];
    expect(removeEntry(list, list[0])).toEqual([list[1]]);
  });
});

describe("totalCards", () => {
  it("sums the staged quantities", () => {
    expect(
      totalCards([
        { setCode: "blb", collectorNumber: "1", ...NONFOIL_EN, quantity: 2, owned: 2 },
        { setCode: "blb", collectorNumber: "2", ...NONFOIL_EN, quantity: 3, owned: 3 },
      ]),
    ).toBe(5);
  });
});

describe("toRemoveCardsRows", () => {
  it("maps staged entries to payload rows", () => {
    expect(
      toRemoveCardsRows([
        { setCode: "blb", collectorNumber: "1", ...NONFOIL_EN, quantity: 2, owned: 5 },
      ]),
    ).toEqual([{ setCode: "blb", collectorNumber: "1", ...NONFOIL_EN, quantity: 2 }]);
  });
});

describe("refreshOwned", () => {
  it("updates owned per staged copy from its printing's copies, marking rows that no longer fit", () => {
    const list = [
      { ...ENTRY, quantity: 2, owned: 3 },
      { ...ENTRY, finish: "foil" as const, quantity: 1, owned: 1 },
      { ...ENTRY, collectorNumber: "2", quantity: 1, owned: 1 },
    ];
    const refreshed = refreshOwned(list, new Map([["blb 1", [OWNED_NONFOIL(1)]]]));

    expect(refreshed).toEqual([
      { ...ENTRY, quantity: 2, owned: 1 },
      { ...ENTRY, finish: "foil", quantity: 1, owned: 0 },
      { ...ENTRY, collectorNumber: "2", quantity: 1, owned: 1 },
    ]);
    expect(refreshed.map(exceedsOwned)).toEqual([true, true, false]);
  });
});

describe("staleMessage", () => {
  it("counts the rows that now exceed what's owned", () => {
    expect(staleMessage([{ ...ENTRY, quantity: 2, owned: 1 }])).toBe(
      "The collection changed since staging: 1 row(s) now exceed what's owned. Adjust or remove them.",
    );
  });

  it("says to retry when nothing exceeds anymore", () => {
    expect(staleMessage([{ ...ENTRY, quantity: 1, owned: 1 }])).toBe(
      "The collection changed since staging; nothing staged exceeds it now — try again.",
    );
  });
});
