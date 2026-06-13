import { Show, createMemo, createSignal } from "solid-js";
import { mapError } from "../data/http/error";
import { useImportCollectionMutation } from "../data/collection_import/mutation";
import { useLatestImportStatusQuery } from "../data/collection_import/query";
import { parseImportRowsCsv } from "./import_rows";

export function ImportPage() {
  const [sourceName, setSourceName] = createSignal("deckstats-export.csv");
  const [rowsCsv, setRowsCsv] = createSignal("M11,146,2");
  const [submitError, setSubmitError] = createSignal<string | null>(null);
  const mutation = useImportCollectionMutation();
  const statusQuery = useLatestImportStatusQuery();

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

    const parsedRows = parseImportRowsCsv(rowsCsv());
    if (parsedRows.error !== null) {
      setSubmitError(parsedRows.error);
      return;
    }

    try {
      const response = await mutation.mutateAsync({
        importRunId: crypto.randomUUID(),
        sourceName: sourceName(),
        sourceChecksum: "manual-upload",
        rowCount: parsedRows.rows.length,
        rows: parsedRows.rows,
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
      <h2>Import</h2>
      <label>
        Source name
        <input value={sourceName()} onInput={(event) => setSourceName(event.currentTarget.value)} />
      </label>
      <label>
        Rows CSV (set_code,collector_number,quantity)
        <textarea
          value={rowsCsv()}
          onInput={(event) => setRowsCsv(event.currentTarget.value)}
          rows={6}
        />
      </label>
      <button onClick={submitImport} disabled={mutation.isPending}>
        Start import
      </button>
      <Show when={submitError() !== null}>
        <p role="alert">{submitError()}</p>
      </Show>
      <p>{statusMessage()}</p>
      <Show when={statusQuery.data?.kind === "found"}>
        <pre>{JSON.stringify(statusQuery.data, null, 2)}</pre>
      </Show>
    </section>
  );
}
