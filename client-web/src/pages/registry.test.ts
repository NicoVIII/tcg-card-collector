// @vitest-environment happy-dom
import { describe, expect, it } from "vitest";
import { pageRegistry } from "./registry";

describe("page registry", () => {
  it("exports an entry for every MVP route", () => {
    const keys = Object.keys(pageRegistry);
    expect(keys).toEqual(["/import", "/catalog", "/inventory", "/settings"]);
  });

  it("all entries are functions (component constructors)", () => {
    for (const [, component] of Object.entries(pageRegistry)) {
      expect(typeof component).toBe("function");
    }
  });
});
