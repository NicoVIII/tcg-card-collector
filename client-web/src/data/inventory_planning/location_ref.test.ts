import { describe, expect, it } from "vitest";
import {
  cascadeLocation,
  fromWireLocationRef,
  locationKey,
  managedLocation,
  parseLocationKey,
} from "./location_ref";

describe("locationKey", () => {
  it("keeps a deck and a binder of the same name apart", () => {
    expect(locationKey(cascadeLocation("Red"))).not.toBe(locationKey(managedLocation("Red")));
  });

  it("round-trips through parseLocationKey, colons in the key included", () => {
    const ref = cascadeLocation("Box A: Row 1");
    expect(parseLocationKey(locationKey(ref))).toEqual(ref);
  });
});

describe("parseLocationKey", () => {
  it("rejects a key without a known kind", () => {
    expect(parseLocationKey("Bulk")).toBeNull();
    expect(parseLocationKey("binder:Bulk")).toBeNull();
  });
});

describe("fromWireLocationRef", () => {
  it("throws on an unknown variant instead of guessing", () => {
    expect(() => fromWireLocationRef({ kind: "UNKNOWN", value: undefined })).toThrow();
  });
});
