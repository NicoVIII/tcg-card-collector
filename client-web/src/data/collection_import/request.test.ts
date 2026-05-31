import { describe, expect, it } from "vitest";
import { normalizeImportCollectionResponse, normalizeLatestImportStatusResponse } from "./request";

describe("collection import request normalization", () => {
  it("maps accepted flag for import command response", () => {
    expect(normalizeImportCollectionResponse({ accepted: true })).toEqual({ accepted: true });
    expect(normalizeImportCollectionResponse({ accepted: 0 })).toEqual({ accepted: false });
    expect(normalizeImportCollectionResponse(null)).toEqual({ accepted: false });
  });

  it("maps snake_case latest status payload to frontend model", () => {
    const result = normalizeLatestImportStatusResponse({
      import_run_id: "run-1",
      source_name: "deckstats-export.csv",
      status: "pending",
      row_count: 42,
    });

    expect(result).toEqual({
      kind: "found",
      run: {
        importRunId: "run-1",
        sourceName: "deckstats-export.csv",
        status: "pending",
        rowCount: 42,
      },
    });
  });

  it("supports wrapped payloads and falls back to not_found", () => {
    expect(
      normalizeLatestImportStatusResponse({
        data: {
          importRunId: "run-2",
          sourceName: "manual-upload",
          status: "succeeded",
          rowCount: 10,
        },
      }),
    ).toEqual({
      kind: "found",
      run: {
        importRunId: "run-2",
        sourceName: "manual-upload",
        status: "succeeded",
        rowCount: 10,
      },
    });

    expect(normalizeLatestImportStatusResponse({ status: "missing-fields" })).toEqual({
      kind: "not_found",
    });
  });
});
