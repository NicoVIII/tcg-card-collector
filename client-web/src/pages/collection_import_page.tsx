import { Show, createSignal } from "solid-js";
import { A } from "@solidjs/router";
import { useImportCollectionMutation } from "../data/collection_import/mutation";
import { mapError } from "../data/http/error";
import { type DeckstatsParseResult, parseDeckstatsCsv } from "./import_deckstats";

function skippedNote(result: DeckstatsParseResult): string | null {
  return result.rejected.length > 0
    ? `${result.rejected.length} line(s) skipped (missing set code or collector number).`
    : null;
}

export function CollectionImportPage() {
  const [parsed, setParsed] = createSignal<DeckstatsParseResult | null>(null);
  const [submitError, setSubmitError] = createSignal<string | null>(null);
  const [successNote, setSuccessNote] = createSignal<string | null>(null);
  const mutation = useImportCollectionMutation();

  const onFileSelected = async (file: File | undefined) => {
    setSubmitError(null);
    setSuccessNote(null);
    if (file === undefined) {
      setParsed(null);
      return;
    }
    setParsed(parseDeckstatsCsv(await file.text()));
  };

  const rowCount = () => parsed()?.rows.length ?? 0;
  const parseError = () => parsed()?.error ?? null;
  const note = () => {
    const result = parsed();
    return result === null ? null : skippedNote(result);
  };
  const canImport = () => parsed() !== null && parseError() === null && rowCount() > 0;

  const submitImport = async () => {
    const parsedFile = parsed();
    if (parsedFile === null || parsedFile.error !== null || parsedFile.rows.length === 0) {
      return;
    }

    setSubmitError(null);
    setSuccessNote(null);
    try {
      const response = await mutation.mutateAsync({ rows: parsedFile.rows });
      if (response.accepted) {
        setSuccessNote(`Imported ${parsedFile.rows.length} card(s).`);
      } else {
        setSubmitError("Import request was rejected.");
      }
    } catch (error) {
      setSubmitError(mapError(error).message);
    }
  };

  return (
    <section>
      <h2>Import collection</h2>
      <p>
        <A href="/collection">← Back to collection</A>
      </p>
      <p>
        Importing replaces the <strong>entire collection</strong> with the file's contents. For
        day-to-day additions, use the add form on the Collection page instead.
      </p>
      <label>
        Collection file (deckstats.net export)
        <input
          type="file"
          accept=".csv,.txt,text/csv"
          onChange={(event) => void onFileSelected(event.currentTarget.files?.[0])}
        />
      </label>
      <Show when={parseError() !== null}>
        <p role="alert">{parseError()}</p>
      </Show>
      <Show when={parsed() !== null && parseError() === null && rowCount() === 0}>
        <p role="alert">The file contains no importable rows.</p>
      </Show>
      <Show when={note()}>
        <p>{note()}</p>
      </Show>
      <Show when={canImport()}>
        <p>{rowCount()} row(s) parsed and ready to import.</p>
        <button onClick={() => void submitImport()} disabled={mutation.isPending}>
          Replace entire collection with {rowCount()} row(s)
        </button>
      </Show>
      <Show when={submitError() !== null}>
        <p role="alert">{submitError()}</p>
      </Show>
      <Show when={successNote() !== null}>
        <p class="success">{successNote()}</p>
      </Show>
    </section>
  );
}
