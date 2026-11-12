import { Show, createSignal } from "solid-js";
import { A } from "@solidjs/router";
import { ConfirmButton } from "../components/confirm_button";
import { DeckShortfallNotice } from "../components/deck_shortfall_notice";
import { LedgerPruneNotice } from "../components/ledger_prune_notice";
import { RejectedList } from "../components/rejected_list";
import { mapError } from "../data/http/error";
import {
  useExportDataMutation,
  useImportDataMutation,
  usePreviewImportMutation,
} from "../data/portability/mutation";
import type { ImportPreview, LedgerPrune, SectionCount } from "../data/portability/request";

// Maps a section's wire name (Portability's own vocabulary, ADR 0019) to
// what the page shows for it — a section this build doesn't know about
// falls back to its wire name rather than disappearing.
const SECTION_LABELS: Record<string, string> = {
  collection: "collection",
  "insights.target_sets": "target sets",
  "inventory_planning.rules": "location rules",
  "inventory_planning.bulk": "bulk spec",
  "inventory_planning.managed_locations": "decks",
  "inventory_planning.managed_location_members": "deck cards",
  "inventory_planning.placed": "placed ledger",
  "inventory_planning.audits": "location audits",
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

// Shared try/catch shape for the two mutations on this page — trims each
// caller down to what's specific to it.
async function runOrReportError<T>(
  action: () => Promise<T>,
  onSuccess: (result: T) => void,
  setError: (message: string) => void,
) {
  try {
    onSuccess(await action());
  } catch (error) {
    setError(mapError(error).message);
  }
}

function ExportSection() {
  const exportMutation = useExportDataMutation();

  return (
    <>
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
    </>
  );
}

// Collection stays the one mandatory section (ADR 0019) — every other
// section is optional, so restoring is only blocked on it being absent or
// empty.
function canRestore(preview: ImportPreview | null): boolean {
  return countFor(preview?.sections ?? [], "collection") > 0;
}

// What a restore will change beyond writing its entries: ledger rows pruned
// right after, decks left short of cards, and audit history the file can't
// give back.
function RestoreWarnings(props: { preview: ImportPreview }) {
  return (
    <>
      <LedgerPruneNotice pruned={props.preview.pruned} done={false} />
      <DeckShortfallNotice shortfall={props.preview.shortfall} />
      <Show when={props.preview.clears_audit_history}>
        <p role="alert">
          This file has no location audits, so restoring it clears when each location was last
          audited.
        </p>
      </Show>
    </>
  );
}

function RestorePreview(props: {
  preview: ImportPreview | null;
  previewPending: boolean;
  importPending: boolean;
  onConfirm: () => void;
}) {
  const restorable = () => canRestore(props.preview);

  return (
    <>
      <Show when={props.previewPending}>
        <p>Checking file…</p>
      </Show>
      <Show when={props.preview !== null}>
        <RejectedList
          items={(props.preview?.rejected ?? []).map((entry) => ({
            label: `${sectionLabel(entry.section)} #${entry.position} (${entry.identity})`,
            reason: entry.reason,
          }))}
        />
        <Show when={!restorable()}>
          <p role="alert">The file has no valid entries to import.</p>
        </Show>
      </Show>
      <Show when={props.preview}>{(preview) => <RestoreWarnings preview={preview()} />}</Show>
      <Show when={restorable()}>
        <p>{summarize(props.preview?.sections ?? [])} ready to restore.</p>
        <ConfirmButton
          label={`Replace ${summarize(props.preview?.sections ?? [])}`}
          disabled={props.importPending}
          onConfirm={props.onConfirm}
        />
      </Show>
    </>
  );
}

export function BackupPage() {
  const previewMutation = usePreviewImportMutation();
  const importMutation = useImportDataMutation();

  const [fileContent, setFileContent] = createSignal<string | null>(null);
  const [preview, setPreview] = createSignal<ImportPreview | null>(null);
  const [restoreError, setRestoreError] = createSignal<string | null>(null);
  const [restoreSuccess, setRestoreSuccess] = createSignal<string | null>(null);
  const [restorePruned, setRestorePruned] = createSignal<LedgerPrune[]>([]);

  const onFileSelected = async (file: File | undefined) => {
    setRestoreError(null);
    setRestoreSuccess(null);
    setRestorePruned([]);
    setPreview(null);
    if (file === undefined) {
      setFileContent(null);
      return;
    }
    const content = await file.text();
    setFileContent(content);
    await runOrReportError(() => previewMutation.mutateAsync(content), setPreview, setRestoreError);
  };

  const submitRestore = async () => {
    const content = fileContent();
    if (content === null || !canRestore(preview())) {
      return;
    }
    setRestoreError(null);
    setRestoreSuccess(null);
    setRestorePruned([]);
    await runOrReportError(
      () => importMutation.mutateAsync(content),
      (result) => {
        setRestoreSuccess(`Restored ${summarize(result.sections)}.`);
        setRestorePruned(result.pruned);
        setFileContent(null);
        setPreview(null);
      },
      setRestoreError,
    );
  };

  return (
    <section>
      <h2>Back up &amp; restore</h2>
      <p>
        <A href="/collection">← Back to collection</A>
      </p>
      <p>
        Downloads everything hand-made in this app — the collection, target sets, location rules,
        bulk spec, and placed ledger — as a single JSON file this app can read back in.
      </p>
      <ExportSection />

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
      <RestorePreview
        preview={preview()}
        previewPending={previewMutation.isPending}
        importPending={importMutation.isPending}
        onConfirm={() => void submitRestore()}
      />
      <Show when={restoreError() !== null}>
        <p role="alert">{restoreError()}</p>
      </Show>
      <Show when={restoreSuccess() !== null}>
        <p class="success">{restoreSuccess()}</p>
        <LedgerPruneNotice pruned={restorePruned()} done={true} />
      </Show>
    </section>
  );
}
