import { describe, expect, it } from "vitest";
import { normalizeSettings } from "./request";

describe("settings request normalization", () => {
  it("returns defaults when payload is null or missing", () => {
    expect(normalizeSettings(null)).toEqual({
      default_sort: "card_name",
      default_grouping: "location_name",
    });
    expect(normalizeSettings(undefined)).toEqual({
      default_sort: "card_name",
      default_grouping: "location_name",
    });
  });

  it("maps snake_case server payload to AppSettings", () => {
    expect(
      normalizeSettings({ default_sort: "set_code", default_grouping: "location_name" }),
    ).toEqual({
      default_sort: "set_code",
      default_grouping: "location_name",
    });
  });

  it("falls back to defaults for missing individual fields", () => {
    expect(normalizeSettings({ default_sort: "quantity" })).toEqual({
      default_sort: "quantity",
      default_grouping: "location_name",
    });
    expect(normalizeSettings({})).toEqual({
      default_sort: "card_name",
      default_grouping: "location_name",
    });
  });
});
