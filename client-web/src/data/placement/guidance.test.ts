import { describe, expect, it } from "vitest";
import type { InventoryProjection, ProjectionCard } from "../inventory_planning/request";
import type { PlacedLedgerRow } from "./request";
import { buildGuidance } from "./guidance";

function card(collector_number: string, quantity: number): ProjectionCard {
  return {
    name: `Card ${collector_number}`,
    set_code: "m11",
    collector_number,
    quantity,
    color_identity: "",
    rarity: "",
    card_type: "",
  };
}

function location(
  location_name: string,
  cards: ProjectionCard[],
): InventoryProjection["locations"][number] {
  return {
    location_name,
    rule_id: "",
    total_quantity: cards.reduce((sum, c) => sum + c.quantity, 0),
    cards,
  };
}

function projection(locations: InventoryProjection["locations"]): InventoryProjection {
  return {
    locations,
    total_quantity: locations.reduce((sum, l) => sum + l.total_quantity, 0),
    unknown_count: 0,
  };
}

function placed(collector_number: string, location: string, quantity: number): PlacedLedgerRow {
  return { set_code: "m11", collector_number, location, quantity };
}

describe("buildGuidance", () => {
  it("subtracts the ledger, drops placed cards, and windows ±1 neighbours", () => {
    const proj = projection([
      location("Bulk", [
        card("146", 1),
        card("147", 1),
        card("148", 1),
        card("149", 1),
        card("150", 1),
      ]),
    ]);
    // 146 and 148 are fully placed here: they drop out but still anchor as
    // already-placed neighbours of the cards that remain.
    const ledger = [placed("146", "Bulk", 1), placed("148", "Bulk", 1)];

    expect(buildGuidance(proj, ledger)).toEqual({
      total_unplaced: 3,
      locations: [
        {
          location_name: "Bulk",
          total_quantity: 3,
          cards: [
            {
              name: "Card 147",
              set_code: "m11",
              collector_number: "147",
              to_place_quantity: 1,
              before: [
                {
                  name: "Card 146",
                  set_code: "m11",
                  collector_number: "146",
                  already_placed: true,
                },
              ],
              after: [
                {
                  name: "Card 148",
                  set_code: "m11",
                  collector_number: "148",
                  already_placed: true,
                },
              ],
            },
            {
              name: "Card 149",
              set_code: "m11",
              collector_number: "149",
              to_place_quantity: 1,
              before: [
                {
                  name: "Card 148",
                  set_code: "m11",
                  collector_number: "148",
                  already_placed: true,
                },
              ],
              after: [
                {
                  name: "Card 150",
                  set_code: "m11",
                  collector_number: "150",
                  already_placed: false,
                },
              ],
            },
            {
              name: "Card 150",
              set_code: "m11",
              collector_number: "150",
              to_place_quantity: 1,
              before: [
                {
                  name: "Card 149",
                  set_code: "m11",
                  collector_number: "149",
                  already_placed: false,
                },
              ],
              after: [],
            },
          ],
        },
      ],
    });
  });

  it("drops fully-placed locations and clamps over-placement at zero", () => {
    const proj = projection([location("Rare", [card("200", 1)])]);
    // The ledger holds more than the projection: to_place and total_unplaced
    // both clamp to zero rather than going negative.
    const ledger = [placed("200", "Rare", 2)];

    expect(buildGuidance(proj, ledger)).toEqual({ locations: [], total_unplaced: 0 });
  });
});
