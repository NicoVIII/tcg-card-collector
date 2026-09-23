import { describe, expect, it } from "vitest";
import { filterFromSearchParams, searchParamsFromFilter, toWireFilter } from "./card_filter";

describe("filterFromSearchParams", () => {
  it("reads name and set from the params", () => {
    expect(filterFromSearchParams({ name: "bolt", set: "lea" })).toEqual({
      name: "bolt",
      set_code: "lea",
    });
  });

  it("defaults missing params to empty strings", () => {
    expect(filterFromSearchParams({})).toEqual({ name: "", set_code: "" });
  });

  it("takes the first value when a param repeats", () => {
    expect(filterFromSearchParams({ name: ["bolt", "shock"] })).toEqual({
      name: "bolt",
      set_code: "",
    });
  });
});

describe("searchParamsFromFilter", () => {
  it("passes trimmed values through", () => {
    expect(searchParamsFromFilter({ name: " bolt ", set_code: " lea " })).toEqual({
      name: "bolt",
      set: "lea",
    });
  });

  it("clears blank or whitespace-only fields to undefined", () => {
    expect(searchParamsFromFilter({ name: "", set_code: "   " })).toEqual({
      name: undefined,
      set: undefined,
    });
  });
});

describe("toWireFilter", () => {
  it("maps a blank filter to nulls", () => {
    expect(toWireFilter({ name: "", set_code: "" })).toEqual({ name: null, setCode: null });
  });

  it("maps a set filter to its camelCase wire fields", () => {
    expect(toWireFilter({ name: "bolt", set_code: "lea" })).toEqual({
      name: "bolt",
      setCode: "lea",
    });
  });
});
