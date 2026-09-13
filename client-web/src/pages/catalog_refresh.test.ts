import { describe, expect, it } from "vitest";
import type { CatalogRefreshStatus } from "../data/card_catalog/request";
import { finishedFeedback, hasFinishedSince, startedFeedback } from "./catalog_refresh";

function status(overrides: Partial<CatalogRefreshStatus> = {}): CatalogRefreshStatus {
  return {
    status: "succeeded",
    last_probe_at: "2026-09-13T10:00:00Z",
    last_upstream_updated_at: "2026-09-13T09:00:00Z",
    error_message: "",
    ...overrides,
  };
}

describe("startedFeedback", () => {
  it("reports a fresh start", () => {
    expect(startedFeedback({ kind: "started" }).message).toBe("Catalog refresh started.");
  });

  it("reports a refresh that was already running", () => {
    expect(startedFeedback({ kind: "already_running" }).message).toBe(
      "A catalog refresh is already running.",
    );
  });
});

describe("finishedFeedback", () => {
  it("is an error carrying the server message when the refresh failed", () => {
    expect(finishedFeedback(status({ status: "failed", error_message: "timeout" }))).toEqual({
      kind: "error",
      message: "Catalog refresh failed: timeout",
    });
  });

  it("is a success naming the outcome otherwise", () => {
    expect(finishedFeedback(status({ status: "skipped" }))).toEqual({
      kind: "success",
      message: "Catalog refresh skipped.",
    });
  });
});

describe("hasFinishedSince", () => {
  it("is false while the probe time still matches the baseline", () => {
    expect(hasFinishedSince(status(), "2026-09-13T10:00:00Z")).toBe(false);
  });

  it("is true once a newer probe was recorded", () => {
    expect(hasFinishedSince(status(), "2026-09-12T10:00:00Z")).toBe(true);
  });

  it("is true for a first-ever refresh against an empty baseline", () => {
    expect(hasFinishedSince(status(), "")).toBe(true);
  });

  it("is false while the catalog has never been refreshed", () => {
    expect(hasFinishedSince(status({ status: "never_run", last_probe_at: "" }), "x")).toBe(false);
  });
});
