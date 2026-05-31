import { Show, createMemo, createSignal } from "solid-js";
import { mapError } from "../data/http/error";
import { useImportCollectionMutation } from "../data/collection_import/mutation";
import { useLatestImportStatusQuery } from "../data/collection_import/query";

export function ImportPage() {
  const [sourceName, setSourceName] = createSignal("deckstats-export.csv");
  const [rowsCsv, setRowsCsv] = createSignal("Lightning Bolt,M11,146,2");
  const [submitError, setSubmitError] = createSignal<string | null>(null);
  const mutation = useImportCollectionMutation();
  const statusQuery = useLatestImportStatusQuery();

  const parseRows = () => {
    const lines = rowsCsv()
      .split("\n")
      .map((line) => line.trim())
      .filter((line) => line.length > 0);

    const rows: Array<{
      cardName: string;
      setCode: string;
      collectorNumber: string;
      quantity: number;
    }> = [];

    for (const line of lines) {
      const [cardNameRaw, setCodeRaw, collectorNumberRaw, quantityRaw] = line
        .split(",")
        .map((part) => part.trim());

      if (!cardNameRaw || !setCodeRaw || !collectorNumberRaw || !quantityRaw) {
        return { rows: [], error: `Invalid row format: ${line}` };
      }

      const quantity = Number.parseInt(quantityRaw, 10);
      if (!Number.isFinite(quantity) || quantity <= 0) {
        return { rows: [], error: `Invalid quantity in row: ${line}` };
      }

      rows.push({
        cardName: cardNameRaw,
        setCode: setCodeRaw,
        collectorNumber: collectorNumberRaw,
        quantity,
      });
    }

    return { rows, error: null as string | null };
  };

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

    const parsedRows = parseRows();
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
        Rows CSV (card_name,set_code,collector_number,quantity)
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
