import { describe, expect, it } from "vitest";
import type { ProjectionSection } from "../data/inventory_planning/request";
import type { PlacementCard, PlacementNeighbor } from "../data/placement/request";
import {
  betweenLabel,
  emptySession,
  isSectionHeader,
  isTicked,
  mergeLocationCards,
  restoreTicks,
  sectionLabel,
  tick,
  tickAll,
  untick,
  untickAll,
  withSectionHeaders,
} from "./placement_session";

function neighbor(
  name: string,
  collector_number: string,
  already_placed: boolean,
  overrides: Partial<Pick<PlacementNeighbor, "finish" | "language">> = {},
): PlacementNeighbor {
  return {
    name,
    set_code: "lea",
    collector_number,
    finish: "nonfoil",
    language: "en",
    already_placed,
    ...overrides,
  };
}

function card(collector_number: string, overrides: Partial<PlacementCard> = {}): PlacementCard {
  return {
    name: `Card ${collector_number}`,
    set_code: "lea",
    collector_number,
    finish: "nonfoil",
    language: "en",
    to_place_quantity: 1,
    before: [],
    after: [],
    section: { parts: [], card_count: 1 },
    ...overrides,
  };
}

describe("placement session ticking", () => {
  it("records and clears a ticked card", () => {
    const c = card("1");
    const ticked = tick(emptySession(), "Bulk", c, 0);

    expect(isTicked(ticked, "Bulk", c)).toBe(true);
    expect(isTicked(untick(ticked, "Bulk", c), "Bulk", c)).toBe(false);
  });

  it("scopes ticks to a location", () => {
    const c = card("1");
    const ticked = tick(emptySession(), "Bulk", c, 0);

    expect(isTicked(ticked, "Binder", c)).toBe(false);
  });

  // A tick on one kind of copy must not read as a tick on another kind of the
  // same printing in the same location (ADR 0010).
  it("scopes ticks to a kind of copy", () => {
    const nonfoil = card("1");
    const foil = card("1", { finish: "foil" });
    const ticked = tick(emptySession(), "Bulk", nonfoil, 0);

    expect(isTicked(ticked, "Bulk", foil)).toBe(false);
  });
});

describe("tickAll / untickAll", () => {
  function tickAllOrThrow(session: ReturnType<typeof emptySession>, cards: PlacementCard[]) {
    const result = tickAll(session, "Bulk", cards);
    if (result === null) {
      throw new Error("expected tickAll to return a batch");
    }
    return result;
  }

  it("ticks every unstruck entry and returns the batch", () => {
    const cards = [card("1"), card("2"), card("3")];

    const { session, batch } = tickAllOrThrow(emptySession(), cards);

    expect(batch.location_name).toBe("Bulk");
    expect(batch.cards.map((c) => c.collector_number)).toEqual(["1", "2", "3"]);
    for (const c of cards) {
      expect(isTicked(session, "Bulk", c)).toBe(true);
    }
  });

  it("skips already-struck entries", () => {
    const already = card("1");
    const fresh = card("2");
    const struckSession = tick(emptySession(), "Bulk", already, 0);

    const { batch } = tickAllOrThrow(struckSession, [already, fresh]);

    expect(batch.cards.map((c) => c.collector_number)).toEqual(["2"]);
  });

  it("returns null when there is nothing left to mark", () => {
    const already = card("1");
    const struckSession = tick(emptySession(), "Bulk", already, 0);

    expect(tickAll(struckSession, "Bulk", [already])).toBeNull();
  });

  it("undoes a mark-all batch as a unit", () => {
    const cards = [card("1"), card("2")];
    const { session: marked, batch } = tickAllOrThrow(emptySession(), cards);

    const restored = untickAll(marked, batch);

    for (const c of cards) {
      expect(isTicked(restored, "Bulk", c)).toBe(false);
    }
  });
});

describe("restoreTicks", () => {
  it("restores a tick that untick removed, at its original index", () => {
    const a = card("1");
    const b = card("2");
    const before = tick(tick(emptySession(), "Bulk", a, 0), "Bulk", b, 1);
    const current = untick(before, "Bulk", b);

    const restored = restoreTicks(current, before, "Bulk", [b]);

    expect(
      mergeLocationCards(restored, "Bulk", [a]).map((entry) => entry.collector_number),
    ).toEqual(["1", "2"]);
  });

  it("removes a tick that was not present before", () => {
    const a = card("1");
    const before = emptySession();
    const current = tick(before, "Bulk", a, 0);

    const restored = restoreTicks(current, before, "Bulk", [a]);

    expect(isTicked(restored, "Bulk", a)).toBe(false);
  });

  it("leaves a tick made after the snapshot untouched", () => {
    const a = card("1");
    const b = card("2");
    const before = emptySession();
    // a is the tick being rolled back; b was ticked afterwards, while a's
    // mutation was still in flight, and must survive the rollback.
    const current = tick(tick(before, "Bulk", a, 0), "Bulk", b, 1);

    const restored = restoreTicks(current, before, "Bulk", [a]);

    expect(isTicked(restored, "Bulk", a)).toBe(false);
    expect(isTicked(restored, "Bulk", b)).toBe(true);
  });

  it("restores a whole mark-all batch as a unit", () => {
    const cards = [card("1"), card("2")];
    const before = emptySession();
    const { session: current, batch } = (() => {
      const result = tickAll(before, "Bulk", cards);
      if (result === null) {
        throw new Error("expected tickAll to return a batch");
      }
      return result;
    })();

    const restored = restoreTicks(current, before, batch.location_name, batch.cards);

    for (const c of cards) {
      expect(isTicked(restored, "Bulk", c)).toBe(false);
    }
  });
});

describe("mergeLocationCards", () => {
  it("re-inserts a ticked card at its recorded index", () => {
    const a = card("1");
    const b = card("2");
    const c = card("3");
    // b was ticked at index 1 and has dropped out of the fresh guidance.
    const session = tick(emptySession(), "Bulk", b, 1);

    const merged = mergeLocationCards(session, "Bulk", [a, c]);

    expect(merged.map((entry) => entry.collector_number)).toEqual(["1", "2", "3"]);
    expect(merged.map((entry) => isTicked(session, "Bulk", entry))).toEqual([false, true, false]);
  });

  it("does not duplicate a ticked card that is still in the fresh guidance", () => {
    const a = card("1");
    const session = tick(emptySession(), "Bulk", a, 0);

    const merged = mergeLocationCards(session, "Bulk", [a]);

    expect(merged).toEqual([a]);
  });

  // Reference stability is the load-bearing invariant of #105: <For> keys by
  // reference, so a card the fresh guidance still lists must come back as the
  // exact same object, not a copy — otherwise every row is torn down and
  // rebuilt on every tick regardless of which one changed.
  it("keeps the same object reference for a card the fresh guidance still lists", () => {
    const a = card("1");
    const b = card("2");

    const merged = mergeLocationCards(emptySession(), "Bulk", [a, b]);

    expect(merged[0]).toBe(a);
    expect(merged[1]).toBe(b);
  });
});

describe("betweenLabel", () => {
  it("anchors between the immediate placed neighbours on each side", () => {
    const c = card("3", {
      before: [neighbor("Near", "2", true)],
      after: [neighbor("Right", "4", true)],
    });

    expect(betweenLabel(emptySession(), "Bulk", c)).toBe("Goes between Near and Right.");
  });

  it("gives consecutive unplaced cards after a placed card distinct hints", () => {
    // A placed card 2 is followed by a run of still-to-place cards 3, 4. Each
    // must anchor on its own immediate predecessor, not both reach back to 2.
    const first = card("3", {
      before: [neighbor("Placed", "2", true)],
      after: [neighbor("Card 4", "4", false)],
    });
    const second = card("4", {
      before: [neighbor("Card 3", "3", false)],
      after: [],
    });

    expect(betweenLabel(emptySession(), "Bulk", first)).toBe("Goes right after Placed.");
    expect(betweenLabel(emptySession(), "Bulk", second)).toBe(
      "Goes after Card 3 — also still to place.",
    );
    expect(betweenLabel(emptySession(), "Bulk", first)).not.toBe(
      betweenLabel(emptySession(), "Bulk", second),
    );
  });

  it("anchors after the placed predecessor when nothing after is placed", () => {
    const c = card("3", {
      before: [neighbor("Near", "2", true)],
      after: [neighbor("New", "4", false)],
    });

    expect(betweenLabel(emptySession(), "Bulk", c)).toBe("Goes right after Near.");
  });

  it("anchors before the placed successor when nothing before is placed", () => {
    const c = card("3", {
      before: [neighbor("New", "2", false)],
      after: [neighbor("Near", "4", true)],
    });

    expect(betweenLabel(emptySession(), "Bulk", c)).toBe("Goes right before Near.");
  });

  it("falls back to still-to-place neighbours when none are placed", () => {
    const c = card("3", {
      before: [neighbor("A", "2", false)],
      after: [neighbor("B", "4", false)],
    });

    expect(betweenLabel(emptySession(), "Bulk", c)).toBe(
      "Goes between A and B — both still to place.",
    );
  });

  it("falls back to the location edge when there are no neighbours", () => {
    expect(betweenLabel(emptySession(), "Bulk", card("1"))).toBe("Only card to place here.");
  });

  it("labels a catalog-gap neighbour by its key", () => {
    const c = card("3", {
      before: [neighbor("", "2", true)],
    });

    expect(betweenLabel(emptySession(), "Bulk", c)).toBe("Goes right after lea 2.");
  });

  // Without the ledger refetch this session relies on (#105, ADR 0015), a
  // neighbour ticked just now must still read as placed — otherwise the very
  // next card's hint would regress the moment you tick the one before it.
  it("anchors on a neighbour ticked this session, before the ledger confirms it", () => {
    const near = card("2");
    const c = card("3", { before: [neighbor("Near", "2", false)] });
    const session = tick(emptySession(), "Bulk", near, 1);

    expect(betweenLabel(session, "Bulk", c)).toBe("Goes right after Near.");
  });

  // A tick on one kind of copy must not anchor a hint for a different kind of
  // the same printing (ADR 0010) — the same guard guidance.ts and resort.ts
  // both carry.
  it("does not anchor on a session tick of a different finish", () => {
    const near = card("2", { finish: "foil" });
    const c = card("3", { before: [neighbor("Near", "2", false, { finish: "nonfoil" })] });
    const session = tick(emptySession(), "Bulk", near, 1);

    expect(betweenLabel(session, "Bulk", c)).toBe("Goes after Near — also still to place.");
  });
});

describe("sectionLabel", () => {
  it("joins parts with a single value each", () => {
    const section: ProjectionSection = {
      parts: [
        { key: "color_identity", first: "R", last: "R" },
        { key: "cmc", first: "3", last: "3" },
      ],
      card_count: 20,
    };
    expect(sectionLabel(section)).toBe("Color R · CMC 3");
  });

  it("shows a merged range as first–last", () => {
    const section: ProjectionSection = {
      parts: [{ key: "cmc", first: "1", last: "3" }],
      card_count: 18,
    };
    expect(sectionLabel(section)).toBe("CMC 1–3");
  });

  it("is empty for a section with no parts", () => {
    expect(sectionLabel({ parts: [], card_count: 40 })).toBe("");
  });
});

describe("withSectionHeaders", () => {
  const sectionA: ProjectionSection = {
    parts: [{ key: "color_identity", first: "R", last: "R" }],
    card_count: 2,
  };
  const sectionB: ProjectionSection = {
    parts: [{ key: "color_identity", first: "U", last: "U" }],
    card_count: 1,
  };
  const emptySectionPart: ProjectionSection = { parts: [], card_count: 1 };

  it("inserts one header before the first card of each section, by reference", () => {
    const cards = [
      card("1", { section: sectionA }),
      card("2", { section: sectionA }),
      card("3", { section: sectionB }),
    ];

    const items = withSectionHeaders(cards);

    expect(items).toEqual([sectionA, cards[0], cards[1], sectionB, cards[2]]);
    expect(items.filter(isSectionHeader)).toEqual([sectionA, sectionB]);
  });

  it("adds no header for a section with no parts", () => {
    const cards = [card("1", { section: emptySectionPart })];

    expect(withSectionHeaders(cards)).toEqual(cards);
  });

  // A struck card stays in the list at its recorded spot (mergeLocationCards)
  // but still carries its original section reference, so its header must not
  // move or duplicate just because the card ahead of it got ticked.
  it("keeps a section's header in place when an earlier card in it drops out", () => {
    const remaining = card("2", { section: sectionA });

    expect(withSectionHeaders([remaining])).toEqual([sectionA, remaining]);
  });
});
