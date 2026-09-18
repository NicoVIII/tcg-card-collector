import { describe, expect, it } from "vitest";
import type { InventoryRule } from "../data/inventory_planning/request";
import {
  applyDraft,
  draftOf,
  emptyDraft,
  isMovable,
  movedOrder,
  nextPosition,
} from "./inventory_rules";

function rule(id: string, position: number, overrides: Partial<InventoryRule> = {}): InventoryRule {
  return {
    id,
    location_name: `Location ${id}`,
    expression: "set_code in (m11)",
    position,
    selector: "all",
    sort_keys: "",
    ...overrides,
  };
}

describe("draftOf / applyDraft", () => {
  it("round-trips the editable fields and leaves id and position alone", () => {
    const original = rule("r1", 3, { location_name: "Binder", expression: "rarity >= rare" });
    const draft = draftOf(original);
    const edited = applyDraft(original, { ...draft, expression: "rarity >= mythic" });

    expect(edited.id).toBe("r1");
    expect(edited.position).toBe(3);
    expect(edited.expression).toBe("rarity >= mythic");
    expect(edited.location_name).toBe("Binder");
  });
});

describe("emptyDraft", () => {
  it("defaults the selector to 'all' and everything else blank", () => {
    expect(emptyDraft()).toEqual({
      location_name: "",
      expression: "",
      selector: "all",
      sort_keys: "",
    });
  });
});

describe("nextPosition", () => {
  it("is 0 for an empty rule list", () => {
    expect(nextPosition([])).toBe(0);
  });

  it("is one past the highest existing position", () => {
    expect(nextPosition([rule("a", 0), rule("b", 4)])).toBe(5);
  });

  it("is robust to duplicate positions (today's data)", () => {
    expect(nextPosition([rule("a", 0), rule("b", 0), rule("c", 0)])).toBe(1);
  });

  it("is robust to gappy positions", () => {
    expect(nextPosition([rule("a", 0), rule("b", 10)])).toBe(11);
  });
});

describe("isMovable", () => {
  const rules = [rule("a", 0), rule("b", 1), rule("c", 2)];

  it("is false moving the first rule up", () => {
    expect(isMovable(rules, "a", -1)).toBe(false);
  });

  it("is false moving the last rule down", () => {
    expect(isMovable(rules, "c", 1)).toBe(false);
  });

  it("is true for a middle rule in either direction", () => {
    expect(isMovable(rules, "b", -1)).toBe(true);
    expect(isMovable(rules, "b", 1)).toBe(true);
  });

  it("is false for an id that isn't in the list", () => {
    expect(isMovable(rules, "missing", 1)).toBe(false);
  });
});

describe("movedOrder", () => {
  const rules = [rule("a", 0), rule("b", 1), rule("c", 2)];

  it("swaps a middle rule with its predecessor", () => {
    expect(movedOrder(rules, "b", -1)).toEqual(["b", "a", "c"]);
  });

  it("swaps a middle rule with its successor", () => {
    expect(movedOrder(rules, "b", 1)).toEqual(["a", "c", "b"]);
  });

  it("leaves the order unchanged moving the first rule up", () => {
    expect(movedOrder(rules, "a", -1)).toEqual(["a", "b", "c"]);
  });

  it("leaves the order unchanged moving the last rule down", () => {
    expect(movedOrder(rules, "c", 1)).toEqual(["a", "b", "c"]);
  });

  it("leaves the order unchanged for an id that isn't listed", () => {
    expect(movedOrder(rules, "missing", 1)).toEqual(["a", "b", "c"]);
  });

  it("moves by list order, not by the position field (duplicate/gappy positions)", () => {
    const messy = [rule("a", 0), rule("b", 0), rule("c", 9)];
    expect(movedOrder(messy, "a", 1)).toEqual(["b", "a", "c"]);
  });
});
