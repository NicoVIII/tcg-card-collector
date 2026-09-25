import { createMutation, useQueryClient } from "@tanstack/solid-query";
import { downloadFile } from "../../lib/download_file";
import { invalidateCollectionDependents } from "../collection/invalidate";
import { fetchExportData, importData, previewImport } from "./request";

// ExportData is a read on the wire (Skir query, no state changes), but the
// client only ever fires it as a one-shot "click to download" action with no
// cacheable result — exactly the createMutation shape every other triggered
// action here uses, not createQuery's.
export function useExportDataMutation() {
  return createMutation(() => ({
    mutationFn: fetchExportData,
    onSuccess: (file) => downloadFile(file.filename, file.content, "application/json"),
  }));
}

// PreviewImport is also a Skir query with no cacheable result — the same
// one-shot rationale as ExportData above.
export function usePreviewImportMutation() {
  return createMutation(() => ({
    mutationFn: (content: string) => previewImport(content),
  }));
}

export function useImportDataMutation() {
  const queryClient = useQueryClient();

  return createMutation(() => ({
    mutationFn: (content: string) => importData(content),
    onSuccess: () => invalidateCollectionDependents(queryClient),
  }));
}
