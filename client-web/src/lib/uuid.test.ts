import { afterEach, describe, expect, it } from "vitest";
import { randomUUID } from "./uuid";

const UUID_V4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

const original = crypto.randomUUID;

function setRandomUUID(fn: typeof crypto.randomUUID | undefined): void {
  (crypto as { randomUUID?: typeof crypto.randomUUID }).randomUUID = fn;
}

describe("randomUUID", () => {
  afterEach(() => {
    setRandomUUID(original);
  });

  it("delegates to crypto.randomUUID when available", () => {
    setRandomUUID(() => "00000000-0000-4000-8000-000000000000");
    expect(randomUUID()).toBe("00000000-0000-4000-8000-000000000000");
  });

  it("falls back to getRandomValues in insecure contexts", () => {
    setRandomUUID(undefined);
    expect(randomUUID()).toMatch(UUID_V4);
  });

  it("produces distinct values from the fallback", () => {
    setRandomUUID(undefined);
    const values = new Set(Array.from({ length: 1000 }, () => randomUUID()));
    expect(values.size).toBe(1000);
  });
});
