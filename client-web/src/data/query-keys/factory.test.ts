import { describe, expect, it } from "vitest";
import { EMPTY_CARD_FILTER } from "../../lib/card_filter";
import { queryKeys } from "./factory";

describe("query key factory", () => {
  it("builds deterministic catalog keys", () => {
    expect(queryKeys.catalogList(EMPTY_CARD_FILTER, 0, 25)).toEqual([
      "card_catalog",
      "list",
      "",
      "",
      0,
      25,
    ]);
  });

  it("bakes the filter into the key, so a different search is a different cache entry", () => {
    expect(queryKeys.catalogList({ name: "bolt", set_code: "lea" }, 0, 25)).toEqual([
      "card_catalog",
      "list",
      "bolt",
      "lea",
      0,
      25,
    ]);
  });

  it("keeps the catalog list prefix aligned with the paged keys", () => {
    expect(queryKeys.catalogList(EMPTY_CARD_FILTER, 0, 25).slice(0, 2)).toEqual([
      ...queryKeys.catalogListAll(),
    ]);
  });

  it("builds a deterministic projection key", () => {
    expect(queryKeys.inventoryProjection()).toEqual(["inventory_planning", "projection"]);
  });

  it("builds a deterministic set completion key", () => {
    expect(queryKeys.setCompletion()).toEqual(["insights", "set_completion"]);
  });

  it("builds a deterministic placed ledger key", () => {
    expect(queryKeys.placedLedger()).toEqual(["inventory_planning", "placed_ledger"]);
  });

  it("builds a deterministic app version key", () => {
    expect(queryKeys.appVersion()).toEqual(["system", "app_version"]);
  });
});
