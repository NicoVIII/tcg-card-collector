import { describe, expect, it } from "vitest";
import type { InventoryProjection, ProjectionCard } from "../data/inventory_planning/request";
import {
  PROJECTION_PAGE_SIZE,
  countLabel,
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
  it("lists every location with its total and bulk flag", () => {
    expect(projectionSummaries(projection())).toEqual([
      { location_name: "binder A", is_bulk: false, total_quantity: 2 },
      { location_name: "Bulk", is_bulk: true, total_quantity: 1 },
    ]);
  });

  it("returns an empty list for an undefined projection", () => {
    expect(projectionSummaries(undefined)).toEqual([]);
  });
});

describe("openLocationCards", () => {
  it("returns null when nothing is open", () => {
    expect(openLocationCards(projection(), null)).toBeNull();
  });

  it("returns null for a name that no longer lists (rule renamed)", () => {
    expect(openLocationCards(projection(), "missing")).toBeNull();
  });

  it("returns the location's cards", () => {
    expect(openLocationCards(projection(), "binder A")).toHaveLength(2);
  });
});

describe("countLabel", () => {
  it("shows the location's total", () => {
    expect(countLabel({ location_name: "binder A", is_bulk: false, total_quantity: 2 })).toBe(
      "2 card(s)",
    );
  });
});

describe("PROJECTION_PAGE_SIZE", () => {
  it("is a positive page size", () => {
    expect(PROJECTION_PAGE_SIZE).toBeGreaterThan(0);
  });
});
