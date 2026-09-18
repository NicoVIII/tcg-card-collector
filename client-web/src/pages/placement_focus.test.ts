import { describe, expect, it } from "vitest";
import type { PlacementCard, PlacementGuidance } from "../data/placement/request";
import { countLabel, focusNameFrom, focusedLocation, locationSummaries } from "./placement_focus";
import { emptySession, tick } from "./placement_session";

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

function guidance(
  locations: { location_name: string; cards: PlacementCard[] }[],
): PlacementGuidance {
  return {
    locations: locations.map((location) => ({
      ...location,
      total_quantity: location.cards.reduce((sum, c) => sum + c.to_place_quantity, 0),
    })),
    total_unplaced: 0,
  };
}

describe("locationSummaries", () => {
  it("keeps cascade order and sums quantity still to place", () => {
    const g = guidance([
      { location_name: "Binder", cards: [card("1", { to_place_quantity: 2 }), card("2")] },
      { location_name: "Bulk", cards: [card("3")] },
    ]);

    expect(locationSummaries(g, emptySession())).toEqual([
      { location_name: "Binder", to_place_quantity: 3 },
      { location_name: "Bulk", to_place_quantity: 1 },
    ]);
  });

  it("appends a session-only location after the guidance-listed ones", () => {
    const c = card("1");
    const g = guidance([{ location_name: "Binder", cards: [card("2")] }]);
    const session = tick(emptySession(), "Box 1", c, 0);

    expect(locationSummaries(g, session).map((s) => s.location_name)).toEqual(["Binder", "Box 1"]);
  });

  it("subtracts a card ticked this session before the ledger refetch lands", () => {
    const a = card("1", { to_place_quantity: 2 });
    const b = card("2", { to_place_quantity: 3 });
    const g = guidance([{ location_name: "Binder", cards: [a, b] }]);
    const session = tick(emptySession(), "Binder", a, 0);

    expect(locationSummaries(g, session)).toEqual([
      { location_name: "Binder", to_place_quantity: 3 },
    ]);
  });

  it("keeps a location the session emptied at zero rather than dropping it", () => {
    const c = card("1");
    const session = tick(emptySession(), "Binder", c, 0);
    // The refetch landed: guidance no longer lists Binder at all.
    const g = guidance([]);

    expect(locationSummaries(g, session)).toEqual([
      { location_name: "Binder", to_place_quantity: 0 },
    ]);
  });

  it("returns nothing while guidance hasn't loaded and nothing is ticked yet", () => {
    expect(locationSummaries(undefined, emptySession())).toEqual([]);
  });
});

describe("countLabel", () => {
  it("shows the quantity when work remains", () => {
    expect(countLabel({ location_name: "Binder", to_place_quantity: 3 })).toBe("3 card(s)");
  });

  it("reads Placed at zero", () => {
    expect(countLabel({ location_name: "Binder", to_place_quantity: 0 })).toBe("Placed");
  });
});

describe("focusNameFrom", () => {
  it("passes a plain name through", () => {
    expect(focusNameFrom("Binder")).toBe("Binder");
  });

  it("normalises undefined and the empty string to null", () => {
    expect(focusNameFrom(undefined)).toBeNull();
    expect(focusNameFrom("")).toBeNull();
  });

  it("takes the first value of a repeated param", () => {
    expect(focusNameFrom(["Binder", "Bulk"])).toBe("Binder");
  });
});

describe("focusedLocation", () => {
  it("returns null when nothing is focused", () => {
    const g = guidance([{ location_name: "Binder", cards: [card("1")] }]);
    expect(focusedLocation(g, emptySession(), null)).toBeNull();
  });

  it("returns null for a name that names no listed location", () => {
    const g = guidance([{ location_name: "Binder", cards: [card("1")] }]);
    expect(focusedLocation(g, emptySession(), "Bulk")).toBeNull();
  });

  it("returns the open location's cards with session ticks merged back in place", () => {
    const a = card("1");
    const b = card("2");
    const c = card("3");
    // b was ticked at index 1 and has dropped out of the fresh guidance.
    const session = tick(emptySession(), "Binder", b, 1);
    const g = guidance([{ location_name: "Binder", cards: [a, c] }]);

    const focused = focusedLocation(g, session, "Binder");

    expect(focused?.cards.map((entry) => [entry.card.collector_number, entry.struck])).toEqual([
      ["1", false],
      ["2", true],
      ["3", false],
    ]);
  });

  it("returns null while guidance hasn't loaded, even with a name in the URL", () => {
    expect(focusedLocation(undefined, emptySession(), "Binder")).toBeNull();
  });
});
