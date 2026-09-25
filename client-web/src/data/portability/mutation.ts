import { createMutation } from "@tanstack/solid-query";
import { downloadFile } from "../../lib/download_file";
import { fetchExportData } from "./request";

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
