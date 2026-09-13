import type { CatalogRefreshStatus, RefreshCatalogResult } from "../data/card_catalog/request";

export type RefreshFeedback = { kind: "success" | "error"; message: string };

export function startedFeedback(result: RefreshCatalogResult): RefreshFeedback {
  return {
    kind: "success",
    message:
      result.kind === "already_running"
        ? "A catalog refresh is already running."
        : "Catalog refresh started.",
  };
}

export function finishedFeedback(status: CatalogRefreshStatus): RefreshFeedback {
  return status.status === "failed"
    ? { kind: "error", message: `Catalog refresh failed: ${status.error_message}` }
    : { kind: "success", message: `Catalog refresh ${status.status}.` };
}

export function hasFinishedSince(status: CatalogRefreshStatus, baseline: string): boolean {
  return status.status !== "never_run" && status.last_probe_at !== baseline;
}
