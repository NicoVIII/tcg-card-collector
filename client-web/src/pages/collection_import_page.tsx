import { Show, createEffect, createMemo, createSignal } from "solid-js";
import { A } from "@solidjs/router";
import { useQueryClient } from "@tanstack/solid-query";
import { useImportCollectionMutation } from "../data/collection_import/mutation";
import { useLatestImportStatusQuery } from "../data/collection_import/query";
import { mapError } from "../data/http/error";
import { queryKeys } from "../data/query-keys/factory";
import { type ParsedImportFile, parseImportFileText } from "./import_file";

export function CollectionImportPage() {
  const queryClient = useQueryClient();
  const [sourceName, setSourceName] = createSignal("");
  const [parsed, setParsed] = createSignal<ParsedImportFile | null>(null);
  const [submitError, setSubmitError] = createSignal<string | null>(null);
  const mutation = useImportCollectionMutation();
  const [isRunPending, setIsRunPending] = createSignal(false);
  const statusQuery = useLatestImportStatusQuery(() => (isRunPending() ? 2000 : false));

  let previousRunStatus: string | undefined;
  createEffect(() => {
    const data = statusQuery.data;
    const status = data?.kind === "found" ? data.run.status : undefined;
    setIsRunPending(status === "pending" || status === "running");

    if (previousRunStatus !== status && (status === "succeeded" || status === "failed")) {
      void queryClient.invalidateQueries({ queryKey: queryKeys.collection() });
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

  const onFileSelected = async (file: File | undefined) => {
    setSubmitError(null);
    if (file === undefined) {
      setParsed(null);
      return;
    }
    setSourceName(file.name);
    setParsed(parseImportFileText(await file.text()));
  };

  const rowCount = () => parsed()?.rows.length ?? 0;
  const parseError = () => parsed()?.error ?? null;
  const canImport = () => parsed() !== null && parseError() === null && rowCount() > 0;

  const submitImport = async () => {
    const parsedFile = parsed();
    if (parsedFile === null || parsedFile.error !== null || parsedFile.rows.length === 0) {
      return;
    }

    setSubmitError(null);
    try {
      const response = await mutation.mutateAsync({
        importRunId: crypto.randomUUID(),
        sourceName: sourceName().trim().length > 0 ? sourceName() : "collection-import",
        rowCount: parsedFile.rows.length,
        rows: parsedFile.rows,
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
      <h2>Import collection</h2>
      <p>
        <A href="/collection">← Back to collection</A>
      </p>
      <p>
        Importing replaces the <strong>entire collection</strong> with the file's contents. For
        day-to-day additions, use the add form on the Collection page instead.
      </p>
      <label>
        Collection file (deckstats.net export or simple CSV)
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
      <Show when={parsed()?.note}>
        <p>{parsed()?.note}</p>
      </Show>
      <Show when={canImport()}>
        <p>{rowCount()} row(s) parsed and ready to import.</p>
        <label>
          Source name
          <input
            value={sourceName()}
            onInput={(event) => setSourceName(event.currentTarget.value)}
          />
        </label>
        <button onClick={() => void submitImport()} disabled={mutation.isPending}>
          Replace entire collection with {rowCount()} row(s)
        </button>
      </Show>
      <Show when={submitError() !== null}>
        <p role="alert">{submitError()}</p>
      </Show>
      <p>{statusMessage()}</p>
    </section>
  );
}
