import { Show } from "solid-js";
import { A } from "@solidjs/router";
import { mapError } from "../data/http/error";
import { useExportDataMutation } from "../data/portability/mutation";

export function BackupPage() {
  const mutation = useExportDataMutation();

  return (
    <section>
      <h2>Back up data</h2>
      <p>
        <A href="/collection">← Back to collection</A>
      </p>
      <p>
        Downloads the collection as a JSON file this app can read back in. Location rules, set
        targets, and the placed ledger aren't included yet.
      </p>
      <button
        type="button"
        onClick={() => mutation.mutate()}
        disabled={mutation.isPending}
        aria-label="Export collection as a JSON file"
      >
        {mutation.isPending ? "Exporting…" : "Export collection"}
      </button>
      <p role="status">{mutation.isSuccess ? "Export downloaded." : ""}</p>
      <Show when={mutation.isError}>
        <p role="alert">{mapError(mutation.error).message}</p>
      </Show>
    </section>
  );
}
