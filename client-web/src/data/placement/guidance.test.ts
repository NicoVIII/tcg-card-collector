import { describe, expect, it } from "vitest";
import type { InventoryProjection, ProjectionCard } from "../inventory_planning/request";
import type { Finish, Language } from "../collection/copy_kind";
import type { PlacedLedgerRow } from "./request";
import { buildGuidance } from "./guidance";

function card(
  collector_number: string,
  quantity: number,
  finish: Finish = "nonfoil",
  language: Language = "en",
): ProjectionCard {
  return {
    name: `Card ${collector_number}`,
    set_code: "m11",
    collector_number,
    finish,
    language,
    quantity,
    color_identity: "",
    rarity: "",
    card_type: "",
  };
}

// A section-less location: the tests below aren't exercising #138's section
// derivation, so every card gets the same empty-parts section (no header).
function location(
  location_name: string,
  cards: ProjectionCard[],
): InventoryProjection["locations"][number] {
  const total_quantity = cards.reduce((sum, c) => sum + c.quantity, 0);
  return {
    location_name,
    rule_id: "",
    total_quantity,
    cards,
    sections: [{ parts: [], card_count: total_quantity }],
  };
}

function projection(locations: InventoryProjection["locations"]): InventoryProjection {
  return {
    locations,
    total_quantity: locations.reduce((sum, l) => sum + l.total_quantity, 0),
    unknown_count: 0,
  };
}

function placed(
  collector_number: string,
  location: string,
  quantity: number,
  finish: Finish = "nonfoil",
  language: Language = "en",
): PlacedLedgerRow {
  return { set_code: "m11", collector_number, finish, language, location, quantity };
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
              finish: "nonfoil",
              language: "en",
              to_place_quantity: 1,
              before: [
                {
                  name: "Card 146",
                  set_code: "m11",
                  collector_number: "146",
                  finish: "nonfoil",
                  language: "en",
                  already_placed: true,
                },
              ],
              after: [
                {
                  name: "Card 148",
                  set_code: "m11",
                  collector_number: "148",
                  finish: "nonfoil",
                  language: "en",
                  already_placed: true,
                },
              ],
              section: { parts: [], card_count: 5 },
            },
            {
              name: "Card 149",
              set_code: "m11",
              collector_number: "149",
              finish: "nonfoil",
              language: "en",
              to_place_quantity: 1,
              before: [
                {
                  name: "Card 148",
                  set_code: "m11",
                  collector_number: "148",
                  finish: "nonfoil",
                  language: "en",
                  already_placed: true,
                },
              ],
              after: [
                {
                  name: "Card 150",
                  set_code: "m11",
                  collector_number: "150",
                  finish: "nonfoil",
                  language: "en",
                  already_placed: false,
                },
              ],
              section: { parts: [], card_count: 5 },
            },
            {
              name: "Card 150",
              set_code: "m11",
              collector_number: "150",
              finish: "nonfoil",
              language: "en",
              to_place_quantity: 1,
              before: [
                {
                  name: "Card 149",
                  set_code: "m11",
                  collector_number: "149",
                  finish: "nonfoil",
                  language: "en",
                  already_placed: false,
                },
              ],
              after: [],
              section: { parts: [], card_count: 5 },
            },
          ],
        },
      ],
    });
  });

  it("drops fully-placed locations and clamps over-placement at zero", () => {
    const proj = projection([location("Rare", [card("200", 1)])]);
    // The ledger holds more than the projection: to_place clamps to zero
    // rather than going negative. The excess is misplaced work, not this
    // module's concern (data/placement/resort.ts).
    const ledger = [placed("200", "Rare", 2)];

    expect(buildGuidance(proj, ledger)).toEqual({ locations: [], total_unplaced: 0 });
  });

  // The regression #107 exists to close: total_unplaced must equal what the
  // location lists actually show, even when the ledger holds copies at a
  // location the projection no longer targets at all.
  it("agrees with the location lists when the ledger holds drift", () => {
    const proj = projection([location("Binder A", [card("161", 2)])]);
    const ledger = [placed("161", "Box 1", 2)];

    const guidance = buildGuidance(proj, ledger);

    expect(guidance.total_unplaced).toBe(
      guidance.locations.reduce((sum, location) => sum + location.total_quantity, 0),
    );
    expect(guidance.total_unplaced).toBe(2);
  });

  // Sections partition the location's full card list, not the still-to-place
  // one — a card's section must stay correct even once an earlier card in
  // the same section has dropped out for being fully placed.
  it("attaches each card's section from the whole location, surviving placed cards dropping out", () => {
    const proj = projection([
      {
        location_name: "Bulk",
        rule_id: "",
        total_quantity: 3,
        cards: [card("146", 1), card("147", 1), card("148", 1)],
        sections: [
          { parts: [{ key: "color_identity", first: "R", last: "R" }], card_count: 2 },
          { parts: [{ key: "color_identity", first: "G", last: "G" }], card_count: 1 },
        ],
      },
    ]);
    const ledger = [placed("146", "Bulk", 1)];

    const guidance = buildGuidance(proj, ledger);
    const [remaining] = guidance.locations[0]!.cards;

    // 147 is the second card of the first (2-copy) section, even though 146
    // — the section's first card — already dropped out of the list above.
    expect(remaining!.collector_number).toBe("147");
    expect(remaining!.section).toEqual({
      parts: [{ key: "color_identity", first: "R", last: "R" }],
      card_count: 2,
    });
  });

  // A tick on one kind of copy must not cancel out another kind's count — the
  // bug this guards against is keying only on (set_code, collector_number).
  it("keeps different finishes of the same printing unplaced independently", () => {
    const proj = projection([
      location("Binder", [card("161", 1, "nonfoil", "en"), card("161", 1, "foil", "en")]),
    ]);
    const ledger = [placed("161", "Binder", 1, "foil", "en")];

    const guidance = buildGuidance(proj, ledger);

    expect(guidance.total_unplaced).toBe(1);
    expect(guidance.locations).toHaveLength(1);
    const [remaining] = guidance.locations[0]!.cards;
    expect(remaining!.finish).toBe("nonfoil");
  });
});
