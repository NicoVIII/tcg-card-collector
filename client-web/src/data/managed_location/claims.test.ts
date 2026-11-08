import { describe, expect, it } from "vitest";
import { claimedTotal, claimsOn, describeClaims, freeCopies } from "./claims";
import type { ManagedLocation } from "./request";

const bolt = {
  set_code: "m11",
  collector_number: "146",
  finish: "nonfoil",
  language: "en",
} as const;

function deck(name: string, quantity: number): ManagedLocation {
  return { id: name, name, kind: "deck", members: [{ ...bolt, quantity }] };
}

describe("deck claims", () => {
  it("sums one copy's claims across every deck", () => {
    const decks = [deck("Burn", 2), deck("Aggro", 1)];
    expect(claimedTotal(decks, bolt)).toBe(3);
    expect(describeClaims(claimsOn(decks, bolt))).toBe("Burn (2), Aggro (1)");
  });

  it("keeps another finish of the same printing out of it", () => {
    expect(claimedTotal([deck("Burn", 2)], { ...bolt, finish: "foil" })).toBe(0);
  });

  it("frees nothing under a shortfall", () => {
    expect(freeCopies(4, [deck("Burn", 3)], bolt)).toBe(1);
    expect(freeCopies(1, [deck("Burn", 3)], bolt)).toBe(0);
  });
});
