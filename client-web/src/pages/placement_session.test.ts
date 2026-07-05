import { describe, expect, it } from "vitest";
import type { PlacementCard, PlacementNeighbor } from "../data/placement/request";
import {
  betweenLabel,
  emptySession,
  isTicked,
  mergeLocationCards,
  tick,
  untick,
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
  it("anchors between the nearest placed neighbours on each side", () => {
    const c = card("3", {
      before: [neighbor("Far", "1", true), neighbor("Near", "2", true)],
      after: [neighbor("Right", "4", true)],
    });

    expect(betweenLabel(c)).toBe("Goes between Near and Right.");
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
