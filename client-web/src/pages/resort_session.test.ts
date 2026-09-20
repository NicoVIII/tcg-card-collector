import { describe, expect, it } from "vitest";
import type { ResortEntry, ResortWorklist } from "../data/placement/resort";
import {
  emptyResortSession,
  filterResortWorklist,
  resolveEntry,
  resolveGroup,
  unresolveEntry,
  unresolveGroup,
} from "./resort_session";

function entry(overrides: Partial<ResortEntry> = {}): ResortEntry {
  return {
    name: "Elvish Mystic",
    set_code: "m11",
    collector_number: "161",
    finish: "nonfoil",
    language: "en",
    quantity: 1,
    destinations: [],
    ...overrides,
  };
}

function worklist(
  groups: { from_location: string; entries: ResortEntry[]; looks_like_rename?: string | null }[],
): ResortWorklist {
  return {
    groups: groups.map((g) => ({ looks_like_rename: null, ...g })),
    total_misplaced: groups.reduce(
      (sum, g) => sum + g.entries.reduce((s, e) => s + e.quantity, 0),
      0,
    ),
  };
}

describe("filterResortWorklist", () => {
  it("passes an unresolved worklist through unchanged", () => {
    const wl = worklist([{ from_location: "Box 1", entries: [entry()] }]);

    expect(filterResortWorklist(wl, emptyResortSession())).toEqual(wl);
  });

  it("drops a resolved entry and its now-empty group", () => {
    const wl = worklist([{ from_location: "Box 1", entries: [entry()] }]);
    const session = resolveEntry(emptyResortSession(), "Box 1", entry());

    expect(filterResortWorklist(wl, session)).toEqual({ groups: [], total_misplaced: 0 });
  });

  it("drops one entry but keeps the group when another entry remains", () => {
    const other = entry({ collector_number: "162" });
    const wl = worklist([{ from_location: "Box 1", entries: [entry(), other] }]);
    const session = resolveEntry(emptyResortSession(), "Box 1", entry());

    const filtered = filterResortWorklist(wl, session);

    expect(filtered.groups).toHaveLength(1);
    expect(filtered.groups[0]!.entries).toEqual([other]);
    expect(filtered.total_misplaced).toBe(1);
  });

  it("drops a resolved group wholesale regardless of its entries", () => {
    const wl = worklist([
      { from_location: "Box 1", entries: [entry(), entry({ collector_number: "162" })] },
    ]);
    const session = resolveGroup(emptyResortSession(), "Box 1");

    expect(filterResortWorklist(wl, session)).toEqual({ groups: [], total_misplaced: 0 });
  });

  it("leaves other groups untouched", () => {
    const wl = worklist([
      { from_location: "Box 1", entries: [entry()] },
      { from_location: "Box 2", entries: [entry({ collector_number: "999" })] },
    ]);
    const session = resolveGroup(emptyResortSession(), "Box 1");

    const filtered = filterResortWorklist(wl, session);

    expect(filtered.groups.map((g) => g.from_location)).toEqual(["Box 2"]);
  });

  it("unresolveEntry and unresolveGroup put things back", () => {
    const wl = worklist([{ from_location: "Box 1", entries: [entry()] }]);
    let session = resolveEntry(emptyResortSession(), "Box 1", entry());
    session = unresolveEntry(session, "Box 1", entry());

    expect(filterResortWorklist(wl, session)).toEqual(wl);

    session = resolveGroup(emptyResortSession(), "Box 1");
    session = unresolveGroup(session, "Box 1");

    expect(filterResortWorklist(wl, session)).toEqual(wl);
  });
});
