// @vitest-environment happy-dom
import { describe, expect, it } from "vitest";
import { navRoutes, routes } from "./routes";

describe("routes", () => {
  it("keeps the nav to the daily-use routes", () => {
    expect(navRoutes.map((route) => route.path)).toEqual([
      "/collection",
      "/catalog",
      "/inventory",
      "/placement",
      "/insights",
    ]);
  });

  it("routes the backup page without putting it in the nav", () => {
    const paths = routes.map((route) => route.path);
    expect(paths).toContain("/backup");
    expect(navRoutes.map((route) => route.path)).not.toContain("/backup");
  });

  it("keeps route labels non-empty", () => {
    for (const route of routes) {
      expect(route.label.length).toBeGreaterThan(0);
    }
  });

  it("contains unique paths only", () => {
    const paths = routes.map((route) => route.path);
    expect(new Set(paths).size).toBe(paths.length);
  });

  it("gives every route a component function", () => {
    for (const route of routes) {
      expect(typeof route.component).toBe("function");
    }
  });
});
