import { Show, createEffect, createMemo, createSignal } from "solid-js";
import { useQueryClient } from "@tanstack/solid-query";
import { mapError } from "../data/http/error";
import { useImportCollectionMutation } from "../data/collection_import/mutation";
import { useLatestImportStatusQuery } from "../data/collection_import/query";
import { useCollectionCardsQuery } from "../data/collection/query";
import { type ImportFormat, detectImportFormat, parseImportRowsCsv } from "./import_rows";
import { parseDeckstatsCsv } from "./import_deckstats";
import type { ImportRow } from "./import_rows";
import { CardGrid } from "../components/card_grid";
import { Pagination } from "../components/pagination";

type ImportFormatChoice = "auto" | ImportFormat;

// Parses the pasted text under the chosen format, returning normalized rows plus
// a human-readable note about anything skipped (deckstats rejected lines).
function parseImportText(
  text: string,
  choice: ImportFormatChoice,
): { rows: ImportRow[]; error: string | null; note: string | null; sourceName: string } {
  const format = choice === "auto" ? detectImportFormat(text) : choice;
  if (format === "deckstats") {
    const result = parseDeckstatsCsv(text);
    const note =
      result.rejected.length > 0
        ? `${result.rejected.length} line(s) skipped (missing set code or collector number).`
        : null;
    return { rows: result.rows, error: result.error, note, sourceName: "deckstats-csv" };
  }
  const result = parseImportRowsCsv(text);
  return { rows: result.rows, error: result.error, note: null, sourceName: "manual" };
}

const PAGE_SIZE = 25;

export function CollectionPage() {
  const queryClient = useQueryClient();

  // import form state
  const [sourceName, setSourceName] = createSignal("");
  const [rowsCsv, setRowsCsv] = createSignal("");
  const [format, setFormat] = createSignal<ImportFormatChoice>("auto");
  const [mode, setMode] = createSignal<"full" | "delta">("full");
  const [submitError, setSubmitError] = createSignal<string | null>(null);
  const [submitNote, setSubmitNote] = createSignal<string | null>(null);
  const mutation = useImportCollectionMutation();
  const [isRunPending, setIsRunPending] = createSignal(false);
  const statusQuery = useLatestImportStatusQuery(() => (isRunPending() ? 2000 : false));

  // collection list state
  const [offset, setOffset] = createSignal(0);
  const cardsQuery = useCollectionCardsQuery(offset, () => PAGE_SIZE);

  const total = () => cardsQuery.data?.total ?? 0;

  let previousRunStatus: string | undefined;
  createEffect(() => {
    const data = statusQuery.data;
    const status = data?.kind === "found" ? data.run.status : undefined;
    setIsRunPending(status === "pending" || status === "running");

    if (previousRunStatus !== status && (status === "succeeded" || status === "failed")) {
      void queryClient.invalidateQueries({ queryKey: ["collection"] });
    }
    previousRunStatus = status;
  });

  const statusMessage = createMemo(() => {
    if (statusQuery.isLoading) {
      return "Loading latest import status...";
    }

    if (statusQuery.isError) {
      return mapError(statusQuery.error).message;
    }

    if (statusQuery.data?.kind !== "found") {
      return "No import has been run yet.";
    }

    const run = statusQuery.data.run;
    return `Last import ${run.importRunId} from ${run.sourceName} is ${run.status} (${run.rowCount} rows).`;
  });

  const submitImport = async () => {
    setSubmitError(null);
    setSubmitNote(null);

    const parsed = parseImportText(rowsCsv(), format());
    setSubmitNote(parsed.note);
    if (parsed.error !== null) {
      setSubmitError(parsed.error);
      return;
    }
    if (parsed.rows.length === 0) {
      setSubmitError("Enter at least one row.");
      return;
    }

    try {
      const response = await mutation.mutateAsync({
        importRunId: crypto.randomUUID(),
        sourceName: sourceName().trim().length > 0 ? sourceName() : parsed.sourceName,
        rowCount: parsed.rows.length,
        rows: parsed.rows,
        mode: mode(),
      });

      if (!response.accepted) {
        setSubmitError("Import request was rejected.");
      }
    } catch (error) {
      setSubmitError(mapError(error).message);
    }
  };

  return (
    <section>
      <h2>Collection</h2>
      <details>
        <summary>Import</summary>
        <label>
          Source name
          <input
            value={sourceName()}
            onInput={(event) => setSourceName(event.currentTarget.value)}
            placeholder="deckstats-export.csv"
          />
        </label>
        <label>
          Format
          <select
            value={format()}
            onChange={(event) => setFormat(event.currentTarget.value as ImportFormatChoice)}
          >
            <option value="auto">Auto-detect</option>
            <option value="simple">Simple (set_code,collector_number,quantity)</option>
            <option value="deckstats">deckstats.net export</option>
          </select>
        </label>
        <label>
          Rows (simple CSV or a pasted deckstats.net export)
          <textarea
            value={rowsCsv()}
            onInput={(event) => setRowsCsv(event.currentTarget.value)}
            rows={6}
            placeholder="M11,146,2"
          />
        </label>
        <fieldset>
          <legend>Import mode</legend>
          <label>
            <input
              type="radio"
              name="import-mode"
              value="full"
              checked={mode() === "full"}
              onChange={() => setMode("full")}
            />
            Full snapshot (replaces the whole collection)
          </label>
          <label>
            <input
              type="radio"
              name="import-mode"
              value="delta"
              checked={mode() === "delta"}
              onChange={() => setMode("delta")}
            />
            Delta (adds to the current collection)
          </label>
        </fieldset>
        <button onClick={submitImport} disabled={mutation.isPending}>
          Start import
        </button>
        <Show when={submitError() !== null}>
          <p role="alert">{submitError()}</p>
        </Show>
        <Show when={submitNote() !== null}>
          <p>{submitNote()}</p>
        </Show>
        <p>{statusMessage()}</p>
      </details>
      <Show when={cardsQuery.isLoading}>
        <p>Loading collection...</p>
      </Show>
      <Show when={cardsQuery.isError}>
        <p role="alert">{mapError(cardsQuery.error).message}</p>
      </Show>
      <Show
        when={(cardsQuery.data?.data?.length ?? 0) > 0}
        fallback={
          <Show when={!cardsQuery.isLoading}>
            <p>No cards in collection.</p>
          </Show>
        }
      >
        <CardGrid cards={cardsQuery.data?.data ?? []} />
        <Pagination
          offset={offset()}
          limit={PAGE_SIZE}
          total={total()}
          onOffsetChange={setOffset}
        />
      </Show>
    </section>
  );
}
