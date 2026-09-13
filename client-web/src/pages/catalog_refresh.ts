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

function padTwo(value: number): string {
  return value.toString().padStart(2, "0");
}

export function formatElapsed(ms: number): string {
  const totalSeconds = Math.max(0, Math.floor(ms / 1000));
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  if (hours > 0) return `${hours}h ${padTwo(minutes)}m`;
  if (minutes > 0) return `${minutes}m ${padTwo(seconds)}s`;
  return `${seconds}s`;
}

export function refreshButtonLabel(elapsedMs: number | null): string {
  return elapsedMs === null ? "Refresh catalog" : `Refreshing… (${formatElapsed(elapsedMs)})`;
}
