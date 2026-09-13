import { describe, expect, it } from "vitest";
import type { CatalogRefreshStatus } from "../data/card_catalog/request";
import {
  finishedFeedback,
  formatElapsed,
  hasFinishedSince,
  refreshButtonLabel,
  startedFeedback,
} from "./catalog_refresh";

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

describe("formatElapsed", () => {
  it("shows seconds under a minute", () => {
    expect(formatElapsed(45_900)).toBe("45s");
  });

  it("shows minutes with padded seconds under an hour", () => {
    expect(formatElapsed(63_000)).toBe("1m 03s");
  });

  it("shows hours with padded minutes beyond that", () => {
    expect(formatElapsed(3_720_000)).toBe("1h 02m");
  });

  it("clamps clock skew below zero to 0s", () => {
    expect(formatElapsed(-500)).toBe("0s");
  });
});

describe("refreshButtonLabel", () => {
  it("offers a refresh when none is in progress", () => {
    expect(refreshButtonLabel(null)).toBe("Refresh catalog");
  });

  it("shows the elapsed time while refreshing", () => {
    expect(refreshButtonLabel(83_000)).toBe("Refreshing… (1m 23s)");
  });
});
