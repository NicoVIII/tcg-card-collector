import { describe, expect, it } from "vitest";
import type { InventoryProjection, ProjectionCard } from "../inventory_planning/request";
import type { Finish, Language } from "../collection/copy_kind";
import type { PlacedLedgerRow } from "./request";
import { buildGuidance } from "./guidance";
import { buildResortWorklist } from "./resort";

function card(
  collector_number: string,
  quantity: number,
  finish: Finish = "nonfoil",
  language: Language = "en",
  name = `Card ${collector_number}`,
): ProjectionCard {
  return {
    name,
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

// A section-less location: none of these tests exercise #138's section
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
  location_name: string,
  quantity: number,
  finish: Finish = "nonfoil",
  language: Language = "en",
): PlacedLedgerRow {
  return { set_code: "m11", collector_number, finish, language, location: location_name, quantity };
}

describe("buildResortWorklist", () => {
  it("lists a re-targeted copy under its stale location with the new destination", () => {
    const proj = projection([
      location("Binder A", [card("161", 1, "nonfoil", "en", "Elvish Mystic")]),
    ]);
    const ledger = [placed("161", "Box 1", 1)];

    const worklist = buildResortWorklist(proj, ledger);

    expect(worklist.total_misplaced).toBe(1);
    expect(worklist.groups).toEqual([
      {
        from_location: "Box 1",
        looks_like_rename: "Binder A",
        entries: [
          {
            name: "Elvish Mystic",
            set_code: "m11",
            collector_number: "161",
            finish: "nonfoil",
            language: "en",
            quantity: 1,
            destinations: [{ location_name: "Binder A", quantity: 1 }],
          },
        ],
      },
    ]);
  });

  it("has no destination and no name when the copy is no longer projected anywhere", () => {
    const proj = projection([]);
    const ledger = [placed("161", "Box 1", 1)];

    const worklist = buildResortWorklist(proj, ledger);

    expect(worklist.total_misplaced).toBe(1);
    expect(worklist.groups[0]!.entries[0]).toMatchObject({ name: "", destinations: [] });
    expect(worklist.groups[0]!.looks_like_rename).toBeNull();
  });

  // The whole stale location's drift maps to exactly one destination and the
  // location itself is gone from the projection — the shape a rename leaves.
  it("flags a group as a likely rename when every entry shares one destination", () => {
    const proj = projection([location("Binder A", [card("161", 1), card("162", 1)])]);
    const ledger = [placed("161", "Box 1", 1), placed("162", "Box 1", 1)];

    const worklist = buildResortWorklist(proj, ledger);

    expect(worklist.groups[0]!.looks_like_rename).toBe("Binder A");
  });

  it("does not flag a rename when the stale location's copies scatter to different destinations", () => {
    const proj = projection([
      location("Binder A", [card("161", 1)]),
      location("Binder B", [card("162", 1)]),
    ]);
    const ledger = [placed("161", "Box 1", 1), placed("162", "Box 1", 1)];

    const worklist = buildResortWorklist(proj, ledger);

    expect(worklist.groups[0]!.looks_like_rename).toBeNull();
  });

  it("does not flag a rename when the stale location still exists in the projection", () => {
    // Binder A still exists (holds card 999) but no longer wants card 161 —
    // partial drift, not a vanished location.
    const proj = projection([
      location("Binder A", [card("999", 1)]),
      location("Binder B", [card("161", 1)]),
    ]);
    const ledger = [placed("161", "Binder A", 1)];

    const worklist = buildResortWorklist(proj, ledger);

    expect(
      worklist.groups.find((g) => g.from_location === "Binder A")!.looks_like_rename,
    ).toBeNull();
  });

  it("does not flag a rename when a misplaced copy has no destination at all", () => {
    const proj = projection([location("Binder A", [card("161", 1)])]);
    // 162 is stranded with nowhere to go; 161's own drift shares one target,
    // but the group as a whole can't be called a clean rename.
    const ledger = [placed("161", "Box 1", 1), placed("162", "Box 1", 1)];

    const worklist = buildResortWorklist(proj, ledger);

    expect(worklist.groups[0]!.looks_like_rename).toBeNull();
  });

  it("sums total_misplaced across groups and copy kinds", () => {
    const proj = projection([location("Binder A", [card("161", 1), card("162", 1, "foil")])]);
    const ledger = [placed("161", "Box 1", 2), placed("162", "Box 2", 3, "foil")];

    const worklist = buildResortWorklist(proj, ledger);

    expect(worklist.total_misplaced).toBe(5);
  });

  // ADR 0010 guard, same as guidance.ts: a foil tick at a stale location must
  // not be read as drift for the nonfoil kind of the same printing.
  it("keeps different finishes of the same printing separate", () => {
    const proj = projection([
      location("Binder A", [card("161", 1, "nonfoil"), card("161", 1, "foil")]),
    ]);
    const ledger = [placed("161", "Box 1", 1, "foil")];

    const worklist = buildResortWorklist(proj, ledger);

    expect(worklist.total_misplaced).toBe(1);
    expect(worklist.groups[0]!.entries[0]!.finish).toBe("foil");
  });

  it("has nothing to report when the ledger matches the projection", () => {
    const proj = projection([location("Binder A", [card("161", 1)])]);
    const ledger = [placed("161", "Binder A", 1)];

    expect(buildResortWorklist(proj, ledger)).toEqual({ groups: [], total_misplaced: 0 });
  });

  // Proves RelocatePlacedCards actually resolves the drift: once the ledger
  // reflects the new location, the same pair reads as fully placed and not
  // misplaced (#107 AC — renaming doesn't strand copies as re-file work).
  it("clears once the ledger is updated to the new location, and guidance shows it placed", () => {
    const proj = projection([location("Binder A", [card("161", 1)])]);
    const relocatedLedger = [placed("161", "Binder A", 1)];

    expect(buildResortWorklist(proj, relocatedLedger)).toEqual({ groups: [], total_misplaced: 0 });
    expect(buildGuidance(proj, relocatedLedger)).toEqual({ locations: [], total_unplaced: 0 });
  });
});
