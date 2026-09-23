import { describe, expect, it } from "vitest";
import { EMPTY_CARD_FILTER, type CardFilter } from "../lib/card_filter";
import type { InventoryProjection, ProjectionCard } from "../data/inventory_planning/request";
import {
  PROJECTION_PAGE_SIZE,
  cardMatches,
  countLabel,
  filterIsActive,
  openLocationCards,
  projectionSummaries,
} from "./inventory_projection";

function card(overrides: Partial<ProjectionCard> = {}): ProjectionCard {
  return {
    name: "Lightning Bolt",
    set_code: "lea",
    collector_number: "162",
    finish: "nonfoil",
    language: "en",
    quantity: 1,
    color_identity: "R",
    rarity: "common",
    card_type: "instant",
    ...overrides,
  };
}

function filter(patch: Partial<CardFilter>): CardFilter {
  return { ...EMPTY_CARD_FILTER, ...patch };
}

describe("cardMatches", () => {
  it("matches on empty filter", () => {
    expect(cardMatches(card(), EMPTY_CARD_FILTER)).toBe(true);
  });

  it("matches name as a case-insensitive substring", () => {
    expect(cardMatches(card({ name: "Lightning Bolt" }), filter({ name: "bolt" }))).toBe(true);
    expect(cardMatches(card({ name: "Lightning Bolt" }), filter({ name: "shock" }))).toBe(false);
  });

  it("matches set code exactly, case-insensitively", () => {
    expect(cardMatches(card({ set_code: "lea" }), filter({ set_code: "LEA" }))).toBe(true);
    expect(cardMatches(card({ set_code: "lea" }), filter({ set_code: "leb" }))).toBe(false);
  });

  it("requires both fields to match when both are set", () => {
    expect(
      cardMatches(
        card({ name: "Lightning Bolt", set_code: "lea" }),
        filter({ name: "bolt", set_code: "leb" }),
      ),
    ).toBe(false);
  });
});

describe("filterIsActive", () => {
  it("is false for the empty filter", () => {
    expect(filterIsActive(EMPTY_CARD_FILTER)).toBe(false);
  });

  it("is true when either field is set", () => {
    expect(filterIsActive(filter({ name: "bolt" }))).toBe(true);
    expect(filterIsActive(filter({ set_code: "lea" }))).toBe(true);
  });
});

function projection(): InventoryProjection {
  return {
    locations: [
      {
        location_name: "binder A",
        rule_id: "rule-1",
        total_quantity: 2,
        cards: [card({ name: "Lightning Bolt" }), card({ name: "Shock", set_code: "m19" })],
      },
      {
        location_name: "Bulk",
        rule_id: "",
        total_quantity: 1,
        cards: [card({ name: "Counterspell", set_code: "leb" })],
      },
    ],
    total_quantity: 3,
    unknown_count: 0,
  };
}

describe("projectionSummaries", () => {
  it("lists every location, with match == total, when the filter is empty", () => {
    expect(projectionSummaries(projection(), EMPTY_CARD_FILTER)).toEqual([
      { location_name: "binder A", is_bulk: false, total_quantity: 2, match_quantity: 2 },
      { location_name: "Bulk", is_bulk: true, total_quantity: 1, match_quantity: 1 },
    ]);
  });

  it("hides locations with no match and reports the match count for the rest", () => {
    expect(projectionSummaries(projection(), filter({ name: "bolt" }))).toEqual([
      { location_name: "binder A", is_bulk: false, total_quantity: 2, match_quantity: 1 },
    ]);
  });

  it("returns an empty list for an undefined projection", () => {
    expect(projectionSummaries(undefined, EMPTY_CARD_FILTER)).toEqual([]);
  });
});

describe("openLocationCards", () => {
  it("returns null when nothing is open", () => {
    expect(openLocationCards(projection(), null, EMPTY_CARD_FILTER)).toBeNull();
  });

  it("returns null for a name that no longer lists (rule renamed)", () => {
    expect(openLocationCards(projection(), "missing", EMPTY_CARD_FILTER)).toBeNull();
  });

  it("returns the location's cards unfiltered", () => {
    expect(openLocationCards(projection(), "binder A", EMPTY_CARD_FILTER)).toHaveLength(2);
  });

  it("filters the open location's cards", () => {
    const cards = openLocationCards(projection(), "binder A", filter({ name: "bolt" }));
    expect(cards).toEqual([card({ name: "Lightning Bolt" })]);
  });

  it("returns null when the filter leaves the open location empty", () => {
    expect(
      openLocationCards(projection(), "binder A", filter({ name: "counterspell" })),
    ).toBeNull();
  });
});

describe("countLabel", () => {
  it("shows just the total when the filter is inactive", () => {
    expect(
      countLabel(
        { location_name: "binder A", is_bulk: false, total_quantity: 2, match_quantity: 2 },
        false,
      ),
    ).toBe("2 card(s)");
  });

  it("shows match of total when the filter is active", () => {
    expect(
      countLabel(
        { location_name: "binder A", is_bulk: false, total_quantity: 2, match_quantity: 1 },
        true,
      ),
    ).toBe("1 of 2 card(s)");
  });
});

describe("PROJECTION_PAGE_SIZE", () => {
  it("is a positive page size", () => {
    expect(PROJECTION_PAGE_SIZE).toBeGreaterThan(0);
  });
});
