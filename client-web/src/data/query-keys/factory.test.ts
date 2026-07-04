import { describe, expect, it } from "vitest";
import { queryKeys } from "./factory";

describe("query key factory", () => {
  it("builds deterministic catalog keys", () => {
    expect(queryKeys.catalogList(0, 25)).toEqual(["card_catalog", "list", 0, 25]);
  });

  it("builds a deterministic projection key", () => {
    expect(queryKeys.inventoryProjection()).toEqual(["inventory_planning", "projection"]);
  });

  it("builds a deterministic set completion key", () => {
    expect(queryKeys.setCompletion()).toEqual(["insights", "set_completion"]);
  });
});
