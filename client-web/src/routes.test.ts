// @vitest-environment happy-dom
import { describe, expect, it } from "vitest";
import { routes } from "./routes";

describe("routes", () => {
  it("exposes the five MVP routes", () => {
    expect(routes.map((route) => route.path)).toEqual([
      "/collection",
      "/catalog",
      "/inventory",
      "/insights",
      "/settings",
    ]);
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
