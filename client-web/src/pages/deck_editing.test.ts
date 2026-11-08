import { describe, expect, it } from "vitest";
import type { InventoryProjection, ProjectionCard } from "../data/inventory_planning/request";
import type { ManagedLocation } from "../data/managed_location/request";
import { additionProblem, deckRows, deckSummary } from "./deck_editing";

const bolt = {
  set_code: "m11",
  collector_number: "146",
  finish: "nonfoil",
  language: "en",
} as const;
const shock = {
  set_code: "m19",
  collector_number: "156",
  finish: "nonfoil",
  language: "en",
} as const;

function card(base: typeof bolt | typeof shock, name: string, quantity: number): ProjectionCard {
  return { ...base, name, quantity, color_identity: "R", rarity: "common", card_type: "instant" };
}

const burn: ManagedLocation = {
  id: "d1",
  name: "Burn",
  kind: "deck",
  members: [
    { ...shock, quantity: 2 },
    { ...bolt, quantity: 1 },
  ],
};

// The deck holds its Bolt; one of its two Shocks is missing.
const projection: InventoryProjection = {
  locations: [
    {
      location: { kind: "managed", key: "d1" },
      location_name: "Burn",
      rule_id: "",
      total_quantity: 2,
      cards: [card(bolt, "Lightning Bolt", 1), card(shock, "Shock", 1)],
      sections: [],
      shortfall: [card(shock, "Shock", 1)],
    },
  ],
  total_quantity: 2,
  unknown_count: 0,
};

describe("deckRows", () => {
  it("marks what the projection says is missing", () => {
    const rows = deckRows(burn, projection);

    expect(rows.map((row) => [row.set_code, row.quantity, row.missing])).toEqual([
      ["m19", 2, 1],
      ["m11", 1, 0],
    ]);
    expect(deckSummary(rows)).toBe("3 card(s), 1 missing");
  });

  it("still lists members before the projection has loaded", () => {
    expect(deckRows(burn, undefined).map((row) => row.missing)).toEqual([0, 0]);
  });
});

describe("additionProblem", () => {
  const entry = {
    setCode: "m11",
    collectorNumber: "146",
    finish: "nonfoil",
    language: "en",
  } as const;
  const owned = [{ finish: "nonfoil", language: "en", quantity: 2 }] as const;

  it("allows copies no deck claims", () => {
    expect(additionProblem({ ...entry, quantity: 1 }, [...owned], [burn])).toBeNull();
  });

  it("refuses copies another deck already holds", () => {
    expect(additionProblem({ ...entry, quantity: 2 }, [...owned], [burn])).toContain(
      "Only 1 of your 2",
    );
  });

  it("says plainly when more are asked for than are owned", () => {
    expect(additionProblem({ ...entry, quantity: 3 }, [...owned], [])).toContain("own only 2");
  });

  it("refuses a copy that isn't owned", () => {
    expect(additionProblem({ ...entry, quantity: 1, finish: "foil" }, [...owned], [])).toContain(
      "don't own",
    );
  });
});
