import { describe, expect, it } from "vitest";
import type { PlacementCard, PlacementNeighbor } from "../data/placement/request";
import {
  betweenLabel,
  emptySession,
  isTicked,
  mergeLocationCards,
  restoreTicks,
  tick,
  tickAll,
  untick,
  untickAll,
  type SessionCard,
} from "./placement_session";

function neighbor(
  name: string,
  collector_number: string,
  already_placed: boolean,
): PlacementNeighbor {
  return { name, set_code: "lea", collector_number, already_placed };
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
  function sessionCard(collector_number: string, struck = false): SessionCard {
    return { card: card(collector_number), struck };
  }

  function tickAllOrThrow(session: ReturnType<typeof emptySession>, cards: SessionCard[]) {
    const result = tickAll(session, "Bulk", cards);
    if (result === null) {
      throw new Error("expected tickAll to return a batch");
    }
    return result;
  }

  it("ticks every unstruck entry and returns the batch", () => {
    const cards = [sessionCard("1"), sessionCard("2"), sessionCard("3")];

    const { session, batch } = tickAllOrThrow(emptySession(), cards);

    expect(batch.location_name).toBe("Bulk");
    expect(batch.cards.map((c) => c.collector_number)).toEqual(["1", "2", "3"]);
    for (const entry of cards) {
      expect(isTicked(session, "Bulk", entry.card)).toBe(true);
    }
  });

  it("skips already-struck entries", () => {
    const cards = [sessionCard("1", true), sessionCard("2")];

    const { batch } = tickAllOrThrow(emptySession(), cards);

    expect(batch.cards.map((c) => c.collector_number)).toEqual(["2"]);
  });

  it("returns null when there is nothing left to mark", () => {
    const cards = [sessionCard("1", true)];

    expect(tickAll(emptySession(), "Bulk", cards)).toBeNull();
  });

  it("undoes a mark-all batch as a unit", () => {
    const cards = [sessionCard("1"), sessionCard("2")];
    const { session: marked, batch } = tickAllOrThrow(emptySession(), cards);

    const restored = untickAll(marked, batch);

    for (const entry of cards) {
      expect(isTicked(restored, "Bulk", entry.card)).toBe(false);
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
      mergeLocationCards(restored, "Bulk", [a]).map((entry) => entry.card.collector_number),
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
    const cards = [
      { card: card("1"), struck: false },
      { card: card("2"), struck: false },
    ];
    const before = emptySession();
    const { session: current, batch } = (() => {
      const result = tickAll(before, "Bulk", cards);
      if (result === null) {
        throw new Error("expected tickAll to return a batch");
      }
      return result;
    })();

    const restored = restoreTicks(current, before, batch.location_name, batch.cards);

    for (const entry of cards) {
      expect(isTicked(restored, "Bulk", entry.card)).toBe(false);
    }
  });
});

describe("mergeLocationCards", () => {
  it("re-inserts a ticked card struck-through at its recorded index", () => {
    const a = card("1");
    const b = card("2");
    const c = card("3");
    // b was ticked at index 1 and has dropped out of the fresh guidance.
    const session = tick(emptySession(), "Bulk", b, 1);

    const merged = mergeLocationCards(session, "Bulk", [a, c]);

    expect(merged.map((entry) => [entry.card.collector_number, entry.struck])).toEqual([
      ["1", false],
      ["2", true],
      ["3", false],
    ]);
  });

  it("does not duplicate a ticked card that is still in the fresh guidance", () => {
    const a = card("1");
    const session = tick(emptySession(), "Bulk", a, 0);

    const merged = mergeLocationCards(session, "Bulk", [a]);

    expect(merged).toEqual([{ card: a, struck: false }]);
  });
});

describe("betweenLabel", () => {
  it("anchors between the immediate placed neighbours on each side", () => {
    const c = card("3", {
      before: [neighbor("Near", "2", true)],
      after: [neighbor("Right", "4", true)],
    });

    expect(betweenLabel(c)).toBe("Goes between Near and Right.");
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

    expect(betweenLabel(first)).toBe("Goes right after Placed.");
    expect(betweenLabel(second)).toBe("Goes after Card 3 — also still to place.");
    expect(betweenLabel(first)).not.toBe(betweenLabel(second));
  });

  it("anchors after the placed predecessor when nothing after is placed", () => {
    const c = card("3", {
      before: [neighbor("Near", "2", true)],
      after: [neighbor("New", "4", false)],
    });

    expect(betweenLabel(c)).toBe("Goes right after Near.");
  });

  it("anchors before the placed successor when nothing before is placed", () => {
    const c = card("3", {
      before: [neighbor("New", "2", false)],
      after: [neighbor("Near", "4", true)],
    });

    expect(betweenLabel(c)).toBe("Goes right before Near.");
  });

  it("falls back to still-to-place neighbours when none are placed", () => {
    const c = card("3", {
      before: [neighbor("A", "2", false)],
      after: [neighbor("B", "4", false)],
    });

    expect(betweenLabel(c)).toBe("Goes between A and B — both still to place.");
  });

  it("falls back to the location edge when there are no neighbours", () => {
    expect(betweenLabel(card("1"))).toBe("Only card to place here.");
  });

  it("labels a catalog-gap neighbour by its key", () => {
    const c = card("3", {
      before: [neighbor("", "2", true)],
    });

    expect(betweenLabel(c)).toBe("Goes right after lea 2.");
  });
});
