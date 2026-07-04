import { describe, expect, it } from "vitest";
import { queryKeys } from "./factory";

describe("query key factory", () => {
  it("builds deterministic catalog keys", () => {
    expect(queryKeys.catalogList(0, 25)).toEqual(["card_catalog", "list", 0, 25]);
  });

  it("builds projection keys with sort and group", () => {
    expect(queryKeys.inventoryProjection("card_name", "location_name")).toEqual([
      "inventory_planning",
      "projection",
      "card_name",
      "location_name",
    ]);
  });

  it("builds a deterministic set completion key", () => {
    expect(queryKeys.setCompletion()).toEqual(["insights", "set_completion"]);
  });
});
