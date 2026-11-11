import { describe, expect, it } from "vitest";
import type { InventoryProjection, ProjectionCard } from "../inventory_planning/request";
import {
  cascadeLocation,
  managedLocation,
  type LocationRef,
} from "../inventory_planning/location_ref";
import type { PlacedLedgerRow } from "../placement/request";
import {
  auditableLocations,
  buildAuditRows,
  ownedQuantities,
  sourceCandidates,
} from "./audit_list";

function card(collector_number: string, quantity: number): ProjectionCard {
  return {
    name: `Card ${collector_number}`,
    set_code: "m11",
    collector_number,
    finish: "nonfoil",
    language: "en",
    quantity,
    color_identity: "",
    rarity: "",
    card_type: "",
  };
}

function location(
  location_name: string,
  cards: ProjectionCard[],
  ref: LocationRef = cascadeLocation(location_name),
): InventoryProjection["locations"][number] {
  const total_quantity = cards.reduce((sum, c) => sum + c.quantity, 0);
  return {
    location: ref,
    location_name,
    rule_id: "",
    total_quantity,
    cards,
    sections: [{ parts: [], card_count: total_quantity }],
    shortfall: [],
  };
}

function projection(locations: InventoryProjection["locations"]): InventoryProjection {
  return { locations, total_quantity: 0, unknown_count: 0 };
}

function placed(
  collector_number: string,
  location: LocationRef,
  quantity: number,
): PlacedLedgerRow {
  return {
    set_code: "m11",
    collector_number,
    finish: "nonfoil",
    language: "en",
    location,
    quantity,
  };
}

const binder = cascadeLocation("Binder");
const deck = managedLocation("d1");

// The binder is sorted 3, 1, 2; the deck holds one 9.
const plan = projection([
  location("Burn", [card("9", 1)], deck),
  location("Binder", [card("3", 1), card("1", 2), card("2", 1)]),
]);

describe("buildAuditRows", () => {
  it("lists the ledger's rows at the location in projected order, misplaced ones last", () => {
    const ledger = [
      placed("1", binder, 2),
      placed("7", binder, 1),
      placed("3", binder, 1),
      placed("9", deck, 1),
    ];

    expect(buildAuditRows(binder, plan, ledger)).toEqual([
      expect.objectContaining({ collector_number: "3", name: "Card 3", recorded: 1 }),
      expect.objectContaining({ collector_number: "1", name: "Card 1", recorded: 2 }),
      expect.objectContaining({ collector_number: "7", name: "", recorded: 1 }),
    ]);
  });
});

describe("auditableLocations", () => {
  it("lists projected locations, then ones only the ledger still records", () => {
    const ledger = [placed("1", binder, 2), placed("5", cascadeLocation("Old box"), 1)];

    expect(auditableLocations(plan, ledger)).toEqual([
      { location: deck, location_name: "Burn", recorded_total: 0 },
      { location: binder, location_name: "Binder", recorded_total: 2 },
      { location: cascadeLocation("Old box"), location_name: "Old box", recorded_total: 1 },
    ]);
  });
});

describe("ownedQuantities", () => {
  it("sums each copy across every location", () => {
    const owned = ownedQuantities(
      projection([location("A", [card("1", 1)]), location("B", [card("1", 2)])]),
    );

    expect(owned.get("m11 1 nonfoil en")).toBe(3);
  });
});

describe("sourceCandidates", () => {
  it("offers every other location recording the copy, by name", () => {
    const ledger = [placed("9", deck, 1), placed("9", binder, 1)];

    expect(
      sourceCandidates(card("9", 1), binder, ledger, auditableLocations(plan, ledger)),
    ).toEqual([{ location: deck, location_name: "Burn", quantity: 1 }]);
  });
});
