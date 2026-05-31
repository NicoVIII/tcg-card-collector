import { Show, createMemo, createSignal } from "solid-js";
import { mapError } from "../data/http/error";
import { useImportCollectionMutation } from "../data/collection_import/mutation";
import { useLatestImportStatusQuery } from "../data/collection_import/query";

export function ImportPage() {
  const [sourceName, setSourceName] = createSignal("deckstats-export.csv");
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

    try {
      const response = await mutation.mutateAsync({
        importRunId: crypto.randomUUID(),
        sourceName: sourceName(),
        sourceChecksum: "manual-upload",
        rowCount: 0,
        rows: [],
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
