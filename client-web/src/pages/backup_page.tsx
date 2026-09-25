import { Show, createSignal } from "solid-js";
import { A } from "@solidjs/router";
import { ConfirmButton } from "../components/confirm_button";
import { RejectedList } from "../components/rejected_list";
import { mapError } from "../data/http/error";
import {
  useExportDataMutation,
  useImportDataMutation,
  usePreviewImportMutation,
} from "../data/portability/mutation";
import type { ImportPreview } from "../data/portability/request";

export function BackupPage() {
  const exportMutation = useExportDataMutation();
  const previewMutation = usePreviewImportMutation();
  const importMutation = useImportDataMutation();

  const [fileContent, setFileContent] = createSignal<string | null>(null);
  const [preview, setPreview] = createSignal<ImportPreview | null>(null);
  const [restoreError, setRestoreError] = createSignal<string | null>(null);
  const [restoreSuccess, setRestoreSuccess] = createSignal<string | null>(null);

  const onFileSelected = async (file: File | undefined) => {
    setRestoreError(null);
    setRestoreSuccess(null);
    setPreview(null);
    if (file === undefined) {
      setFileContent(null);
      return;
    }
    const content = await file.text();
    setFileContent(content);
    try {
      setPreview(await previewMutation.mutateAsync(content));
    } catch (error) {
      setRestoreError(mapError(error).message);
    }
  };

  const canRestore = () => (preview()?.entryCount ?? 0) > 0;

  const submitRestore = async () => {
    const content = fileContent();
    if (content === null || !canRestore()) {
      return;
    }
    setRestoreError(null);
    setRestoreSuccess(null);
    try {
      const result = await importMutation.mutateAsync(content);
      setRestoreSuccess(`Restored ${result.entryCount} entry(ies).`);
      setFileContent(null);
      setPreview(null);
    } catch (error) {
      setRestoreError(mapError(error).message);
    }
  };

  return (
    <section>
      <h2>Back up &amp; restore</h2>
      <p>
        <A href="/collection">← Back to collection</A>
      </p>
      <p>
        Downloads the collection as a JSON file this app can read back in. Location rules, set
        targets, and the placed ledger aren't included yet.
      </p>
      <button
        type="button"
        onClick={() => exportMutation.mutate()}
        disabled={exportMutation.isPending}
        aria-label="Export collection as a JSON file"
      >
        {exportMutation.isPending ? "Exporting…" : "Export collection"}
      </button>
      <p role="status">{exportMutation.isSuccess ? "Export downloaded." : ""}</p>
      <Show when={exportMutation.isError}>
        <p role="alert">{mapError(exportMutation.error).message}</p>
      </Show>

      <h3>Restore from file</h3>
      <p>
        Restoring replaces the <strong>entire collection</strong> with the file's contents.
      </p>
      <label>
        Export file
        <input
          type="file"
          accept=".json,application/json"
          onChange={(event) => void onFileSelected(event.currentTarget.files?.[0])}
        />
      </label>
      <Show when={previewMutation.isPending}>
        <p>Checking file…</p>
      </Show>
      <Show when={preview() !== null}>
        <RejectedList
          items={(preview()?.rejected ?? []).map((entry) => ({
            label: `Entry ${entry.position} (${entry.identity})`,
            reason: entry.reason,
          }))}
        />
        <Show when={!canRestore()}>
          <p role="alert">The file has no valid entries to import.</p>
        </Show>
      </Show>
      <Show when={canRestore()}>
        <p>{preview()?.entryCount} entry(ies) ready to restore.</p>
        <ConfirmButton
          label={`Replace entire collection with ${preview()?.entryCount} entry(ies)`}
          disabled={importMutation.isPending}
          onConfirm={() => void submitRestore()}
        />
      </Show>
      <Show when={restoreError() !== null}>
        <p role="alert">{restoreError()}</p>
      </Show>
      <Show when={restoreSuccess() !== null}>
        <p class="success">{restoreSuccess()}</p>
      </Show>
    </section>
  );
}
