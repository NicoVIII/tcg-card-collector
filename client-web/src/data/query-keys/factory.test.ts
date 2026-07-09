import { describe, expect, it } from "vitest";
import { queryKeys } from "./factory";

describe("query key factory", () => {
  it("builds deterministic catalog keys", () => {
    expect(queryKeys.catalogList(0, 25)).toEqual(["card_catalog", "list", 0, 25]);
  });

  it("keeps the catalog list prefix aligned with the paged keys", () => {
    expect(queryKeys.catalogList(0, 25).slice(0, 2)).toEqual([...queryKeys.catalogListAll()]);
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
});
