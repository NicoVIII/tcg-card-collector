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
import type { ImportPreview, SectionCount } from "../data/portability/request";

// Maps a section's wire name (Portability's own vocabulary, ADR 0019) to
// what the page shows for it — a section this build doesn't know about
// falls back to its wire name rather than disappearing.
const SECTION_LABELS: Record<string, string> = {
  collection: "collection",
  "insights.target_sets": "target sets",
};

function sectionLabel(section: string): string {
  return SECTION_LABELS[section] ?? section;
}

function countFor(sections: SectionCount[], section: string): number {
  return sections.find((entry) => entry.section === section)?.count ?? 0;
}

function summarize(sections: SectionCount[]): string {
  return sections.map((entry) => `${entry.count} ${sectionLabel(entry.section)}`).join(", ");
}

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

  // Collection stays the one mandatory section (ADR 0019) — every other
  // section is optional, so restoring is only blocked on it being absent
  // or empty.
  const canRestore = () => countFor(preview()?.sections ?? [], "collection") > 0;

  const submitRestore = async () => {
    const content = fileContent();
    if (content === null || !canRestore()) {
      return;
    }
    setRestoreError(null);
    setRestoreSuccess(null);
    try {
      const result = await importMutation.mutateAsync(content);
      setRestoreSuccess(`Restored ${summarize(result.sections)}.`);
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
        Downloads the collection and target sets as a JSON file this app can read back in. Location
        rules and the placed ledger aren't included yet.
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
        Restoring replaces the <strong>entire collection</strong>, and any other section the file
        contains — a section the file doesn't have is left untouched.
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
            label: `${sectionLabel(entry.section)} #${entry.position} (${entry.identity})`,
            reason: entry.reason,
          }))}
        />
        <Show when={!canRestore()}>
          <p role="alert">The file has no valid entries to import.</p>
        </Show>
      </Show>
      <Show when={canRestore()}>
        <p>{summarize(preview()?.sections ?? [])} ready to restore.</p>
        <ConfirmButton
          label={`Replace ${summarize(preview()?.sections ?? [])}`}
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
