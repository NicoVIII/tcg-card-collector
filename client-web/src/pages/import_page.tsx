import { createSignal } from "solid-js";
import { mapError } from "../data/http/error";
import { useImportCollectionMutation } from "../data/collection_import/mutation";
import { useLatestImportStatusQuery } from "../data/collection_import/query";

export function ImportPage() {
  const [sourceName, setSourceName] = createSignal("deckstats-export.csv");
  const mutation = useImportCollectionMutation();
  const statusQuery = useLatestImportStatusQuery();

  const submitImport = async () => {
    try {
      await mutation.mutateAsync({
        importRunId: crypto.randomUUID(),
        sourceName: sourceName(),
        sourceChecksum: "manual-upload",
        rowCount: 0,
      });
    } catch (error) {
      console.error(mapError(error));
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
      <pre>{JSON.stringify(statusQuery.data, null, 2)}</pre>
    </section>
  );
}
