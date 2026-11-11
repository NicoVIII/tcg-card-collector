import { describe, expect, it } from "vitest";
import { cascadeLocation, managedLocation } from "../data/inventory_planning/location_ref";
import type { PlacedLedgerRow } from "../data/placement/request";
import type { RemovalSource } from "./remove_cards_sources";
import {
  type StagedEntry,
  chooseSource,
  exceedsOwned,
  needsSource,
  refreshStaged,
  stageEntry,
  toUnmarkPlacements,
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
const UNPLACED = (available: number): RemovalSource => ({ kind: "unplaced", available });
const BINDER = (available: number): RemovalSource => ({
  kind: "placed",
  location: cascadeLocation("Binder"),
  name: "Binder",
  available,
});
const BOX = (available: number): RemovalSource => ({
  kind: "placed",
  location: cascadeLocation("Box"),
  name: "Box",
  available,
});
const LEDGER_ROW = (
  location: string,
  quantity: number,
  collectorNumber = "1",
): PlacedLedgerRow => ({
  set_code: "blb",
  collector_number: collectorNumber,
  ...NONFOIL_EN,
  location: cascadeLocation(location),
  quantity,
});
// A line whose copies can only have come off the unplaced pile — what every
// staging against an empty ledger produces.
const UNPLACED_LINE = (fields: Partial<StagedEntry> & { quantity: number; owned: number }) => ({
  ...ENTRY,
  sources: [UNPLACED(fields.owned)],
  source: UNPLACED(fields.owned),
  ...fields,
});

describe("stageEntry", () => {
  it("appends a new card at the end, recording the owned quantity", () => {
    const first = stageEntry([], { ...ENTRY, quantity: 2 }, [OWNED_NONFOIL(3)], [], []);
    expect(first).toEqual({ ok: true, list: [UNPLACED_LINE({ quantity: 2, owned: 3 })] });
    if (!first.ok) throw new Error("unreachable");

    expect(
      stageEntry(
        first.list,
        { ...ENTRY, collectorNumber: "2", quantity: 1 },
        [OWNED_NONFOIL(1)],
        [],
        [],
      ),
    ).toEqual({
      ok: true,
      list: [
        UNPLACED_LINE({ quantity: 2, owned: 3 }),
        UNPLACED_LINE({ collectorNumber: "2", quantity: 1, owned: 1 }),
      ],
    });
  });

  it("sums quantities when the same copy is already staged from the same source", () => {
    const staged = [UNPLACED_LINE({ quantity: 2, owned: 5 })];
    expect(stageEntry(staged, { ...ENTRY, quantity: 3 }, [OWNED_NONFOIL(5)], [], [])).toEqual({
      ok: true,
      list: [UNPLACED_LINE({ quantity: 5, owned: 5 })],
    });
  });

  it("keeps a different finish as a separate staged line", () => {
    const staged = [UNPLACED_LINE({ quantity: 2, owned: 2 })];
    const result = stageEntry(
      staged,
      { ...ENTRY, finish: "foil", quantity: 1 },
      [OWNED_NONFOIL(2), { finish: "foil", language: "en", quantity: 1 }],
      [],
      [],
    );
    expect(result).toEqual({
      ok: true,
      list: [
        UNPLACED_LINE({ quantity: 2, owned: 2 }),
        UNPLACED_LINE({ finish: "foil", quantity: 1, owned: 1 }),
      ],
    });
  });

  it("refuses a printing that isn't owned at all", () => {
    expect(stageEntry([], { ...ENTRY, quantity: 1 }, [], [], [])).toEqual({
      ok: false,
      message: "You don't own blb 1 (nonfoil·en).",
    });
  });

  it("refuses an owned printing in a finish or language that isn't owned, naming what is", () => {
    expect(
      stageEntry(
        [],
        { ...ENTRY, quantity: 1 },
        [{ finish: "foil", language: "de", quantity: 1 }],
        [],
        [],
      ),
    ).toEqual({
      ok: false,
      message: "You don't own blb 1 (nonfoil·en); you own it as foil·de.",
    });
  });

  it("refuses a quantity above the owned one", () => {
    expect(stageEntry([], { ...ENTRY, quantity: 4 }, [OWNED_NONFOIL(3)], [], [])).toEqual({
      ok: false,
      message: "Only 3 owned.",
    });
  });

  it("counts every line already staged for the copy against the owned quantity", () => {
    const staged = [
      { ...ENTRY, quantity: 1, owned: 3, sources: [BINDER(1), BOX(2)], source: BINDER(1) },
      { ...ENTRY, quantity: 1, owned: 3, sources: [BINDER(1), BOX(2)], source: BOX(2) },
    ];
    expect(stageEntry(staged, { ...ENTRY, quantity: 2 }, [OWNED_NONFOIL(3)], [], [])).toEqual({
      ok: false,
      message: "Only 3 owned (2 already staged).",
    });
  });

  it("preselects the one location a fully placed copy can come from", () => {
    const result = stageEntry(
      [],
      { ...ENTRY, quantity: 1 },
      [OWNED_NONFOIL(2)],
      [],
      [LEDGER_ROW("Binder", 2)],
    );
    expect(result).toEqual({
      ok: true,
      list: [{ ...ENTRY, quantity: 1, owned: 2, sources: [BINDER(2)], source: BINDER(2) }],
    });
  });

  // One placed location plus unplaced copies is already ambiguous: taking
  // the binder's copy must unmark it, taking a loose one must not.
  it("leaves the source unpicked when the copies could come from more than one place", () => {
    const result = stageEntry(
      [],
      { ...ENTRY, quantity: 1 },
      [OWNED_NONFOIL(2)],
      [],
      [LEDGER_ROW("Binder", 1)],
    );
    expect(result).toEqual({
      ok: true,
      list: [{ ...ENTRY, quantity: 1, owned: 2, sources: [BINDER(1), UNPLACED(1)], source: null }],
    });
    expect(result.ok && result.list.map(needsSource)).toEqual([true]);
  });
});

describe("chooseSource", () => {
  const unpicked = (quantity: number): StagedEntry => ({
    ...ENTRY,
    quantity,
    owned: 3,
    sources: [BINDER(1), BOX(2)],
    source: null,
  });

  it("sets the line's source", () => {
    const line = unpicked(1);
    expect(chooseSource([line], line, BOX(2))).toEqual({
      ok: true,
      list: [{ ...line, source: BOX(2) }],
    });
  });

  it("merges into a line already taking the copy from that source", () => {
    const picked = { ...unpicked(1), source: BOX(2) };
    const line = unpicked(1);
    expect(chooseSource([picked, line], line, BOX(2))).toEqual({
      ok: true,
      list: [{ ...line, quantity: 2, source: BOX(2) }],
    });
  });

  it("refuses a source holding fewer copies than its lines would take", () => {
    const line = unpicked(2);
    expect(chooseSource([line], line, BINDER(1))).toEqual({
      ok: false,
      message:
        "Only 1 of blb 1 (nonfoil·en) are recorded in Binder; stage the rest as their own line.",
    });
  });
});

describe("removeEntry", () => {
  it("removes exactly the matching line", () => {
    const list = [
      UNPLACED_LINE({ quantity: 2, owned: 2 }),
      UNPLACED_LINE({ collectorNumber: "2", quantity: 1, owned: 1 }),
    ];
    expect(removeEntry(list, list[0])).toEqual([list[1]]);
  });

  it("keeps the same copy's line from another source", () => {
    const list: StagedEntry[] = [
      { ...ENTRY, quantity: 1, owned: 3, sources: [BINDER(1), BOX(2)], source: BINDER(1) },
      { ...ENTRY, quantity: 1, owned: 3, sources: [BINDER(1), BOX(2)], source: BOX(2) },
    ];
    expect(removeEntry(list, list[0])).toEqual([list[1]]);
  });
});

describe("totalCards", () => {
  it("sums the staged quantities", () => {
    expect(
      totalCards([
        UNPLACED_LINE({ quantity: 2, owned: 2 }),
        UNPLACED_LINE({ collectorNumber: "2", quantity: 3, owned: 3 }),
      ]),
    ).toBe(5);
  });
});

describe("toRemoveCardsRows", () => {
  it("maps staged entries to payload rows", () => {
    expect(toRemoveCardsRows([UNPLACED_LINE({ quantity: 2, owned: 5 })])).toEqual([
      { setCode: "blb", collectorNumber: "1", ...NONFOIL_EN, quantity: 2 },
    ]);
  });
});

describe("toUnmarkPlacements", () => {
  it("unmarks only lines taken from a placed location", () => {
    expect(
      toUnmarkPlacements([
        { ...ENTRY, quantity: 1, owned: 3, sources: [BINDER(1), UNPLACED(2)], source: BINDER(1) },
        { ...ENTRY, quantity: 2, owned: 3, sources: [BINDER(1), UNPLACED(2)], source: UNPLACED(2) },
      ]),
    ).toEqual([
      {
        set_code: "blb",
        collector_number: "1",
        ...NONFOIL_EN,
        location: cascadeLocation("Binder"),
        quantity: 1,
      },
    ]);
  });
});

describe("refreshStaged", () => {
  it("updates owned per staged copy from its printing's copies, marking rows that no longer fit", () => {
    const list = [
      UNPLACED_LINE({ quantity: 2, owned: 3 }),
      UNPLACED_LINE({ finish: "foil", quantity: 1, owned: 1 }),
      UNPLACED_LINE({ collectorNumber: "2", quantity: 1, owned: 1 }),
    ];
    const refreshed = refreshStaged(list, new Map([["blb 1", [OWNED_NONFOIL(1)]]]), [], []);

    expect(refreshed.map((entry) => entry.owned)).toEqual([1, 0, 1]);
    expect(refreshed.map(exceedsOwned)).toEqual([true, true, false]);
  });

  it("keeps a picked source that still holds the line's copies", () => {
    const line = { ...ENTRY, quantity: 1, owned: 3, sources: [BINDER(1), BOX(2)], source: BOX(2) };
    const refreshed = refreshStaged(
      [line],
      new Map([["blb 1", [OWNED_NONFOIL(3)]]]),
      [LEDGER_ROW("Binder", 1), LEDGER_ROW("Box", 2)],
      [],
    );
    expect(refreshed).toEqual([line]);
  });

  it("unpicks a source the fresh ledger no longer backs, merging the unpicked lines", () => {
    const list: StagedEntry[] = [
      { ...ENTRY, quantity: 1, owned: 3, sources: [BINDER(1), BOX(2)], source: BINDER(1) },
      { ...ENTRY, quantity: 1, owned: 3, sources: [BINDER(1), BOX(2)], source: null },
    ];
    const refreshed = refreshStaged(
      list,
      new Map([["blb 1", [OWNED_NONFOIL(3)]]]),
      [LEDGER_ROW("Box", 2)],
      [],
    );
    expect(refreshed).toEqual([
      { ...ENTRY, quantity: 2, owned: 3, sources: [BOX(2), UNPLACED(1)], source: null },
    ]);
    expect(staleMessage(refreshed)).toBe(
      "The collection or its placements changed since staging: pick again where 1 row(s) were taken from.",
    );
  });
});

describe("staleMessage", () => {
  it("counts the rows that now exceed what's owned", () => {
    expect(staleMessage([UNPLACED_LINE({ quantity: 2, owned: 1 })])).toBe(
      "The collection changed since staging: 1 row(s) now exceed what's owned. Adjust or remove them.",
    );
  });

  it("says to retry when nothing exceeds anymore", () => {
    expect(staleMessage([UNPLACED_LINE({ quantity: 1, owned: 1 })])).toBe(
      "The collection changed since staging; nothing staged exceeds it now — try again.",
    );
  });
});

describe("stageEntry's deck guard", () => {
  const deck = (quantity: number) => ({
    id: "d1",
    name: "Mono-Red",
    kind: "deck" as const,
    members: [
      {
        set_code: ENTRY.setCode,
        collector_number: ENTRY.collectorNumber,
        finish: ENTRY.finish,
        language: ENTRY.language,
        quantity,
      },
    ],
  });

  it("stages copies no deck claims", () => {
    expect(stageEntry([], { ...ENTRY, quantity: 1 }, [OWNED_NONFOIL(3)], [deck(2)], []).ok).toBe(
      true,
    );
  });

  // Removing a deck's copy would leave the deck short without the user
  // deciding that (ADR 0022), so it's refused and the deck is named.
  it("refuses a removal that would cut into a deck and names the deck", () => {
    const result = stageEntry([], { ...ENTRY, quantity: 2 }, [OWNED_NONFOIL(3)], [deck(2)], []);

    expect(result.ok).toBe(false);
    expect(!result.ok && result.message).toContain("Mono-Red (2)");
  });
});

describe("stageEntry's sources around decks", () => {
  // The deck still claims 1 of the 2 placed in it; the other sits in the
  // deck but is free, so the deck is a real source for it.
  it("offers a deck's placed copies beyond what it claims", () => {
    const deck = {
      id: "d1",
      name: "Mono-Red",
      kind: "deck" as const,
      members: [{ set_code: "blb", collector_number: "1", ...NONFOIL_EN, quantity: 1 }],
    };
    const ledger = [{ ...LEDGER_ROW("Binder", 1), location: managedLocation("d1"), quantity: 2 }];
    const result = stageEntry([], { ...ENTRY, quantity: 1 }, [OWNED_NONFOIL(3)], [deck], ledger);

    expect(result.ok && result.list[0].sources).toEqual([
      { kind: "placed", location: managedLocation("d1"), name: "Mono-Red", available: 1 },
      UNPLACED(1),
    ]);
  });
});
