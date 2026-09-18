import { For, Show, createSignal } from "solid-js";
import { ConfirmButton } from "../components/confirm_button";
import { mapError } from "../data/http/error";
import { useMarkTargetSetMutation, useUnmarkTargetSetMutation } from "../data/insights/mutation";
import { useSetCompletionQuery } from "../data/insights/query";
import { createMutationError } from "../lib/mutation_error";

export function InsightsPage() {
  const completionQuery = useSetCompletionQuery();
  const markMutation = useMarkTargetSetMutation();
  const unmarkMutation = useUnmarkTargetSetMutation();

  const [newSetCode, setNewSetCode] = createSignal("");
  const formError = createMutationError();

  const addTargetSet = async () => {
    formError.clear();
    const setCode = newSetCode().trim();
    if (setCode.length === 0) {
      formError.report(new Error("Enter a set code."));
      return;
    }

    try {
      const response = await markMutation.mutateAsync(setCode);
      if (!response.success) {
        formError.report(new Error("Could not add set as a target."));
        return;
      }
      setNewSetCode("");
    } catch (error) {
      formError.report(error);
    }
  };

  const removeTargetSet = async (setCode: string) => {
    formError.clear();
    try {
      await unmarkMutation.mutateAsync(setCode);
    } catch (error) {
      formError.report(error);
    }
  };

  return (
    <section>
      <h2>Insights</h2>
      <label>
        Track a set
        <input
          value={newSetCode()}
          onInput={(event) => setNewSetCode(event.currentTarget.value)}
          placeholder="lea"
        />
      </label>
      <button onClick={addTargetSet} disabled={markMutation.isPending}>
        Add target set
      </button>
      <Show when={formError.messageFor() !== null}>
        <p role="alert">{formError.messageFor()}</p>
      </Show>
      <Show when={completionQuery.isLoading}>
        <p>Loading set completion...</p>
      </Show>
      <Show when={completionQuery.isError}>
        <p role="alert">{mapError(completionQuery.error).message}</p>
      </Show>
      <Show
        when={(completionQuery.data?.length ?? 0) > 0}
        fallback={
          <Show when={!completionQuery.isLoading}>
            <p>No target sets yet.</p>
          </Show>
        }
      >
        <ul>
          <For each={completionQuery.data}>
            {(row) => (
              <li>
                {row.set_code}: {row.owned} / {row.total ?? "—"}
                <ConfirmButton
                  label="Remove"
                  ariaLabel={`Remove target set ${row.set_code}`}
                  disabled={unmarkMutation.isPending}
                  onConfirm={() => void removeTargetSet(row.set_code)}
                />
              </li>
            )}
          </For>
        </ul>
      </Show>
    </section>
  );
}
