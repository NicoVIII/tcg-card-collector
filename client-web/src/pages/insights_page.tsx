import { For, Show, createSignal } from "solid-js";
import { mapError } from "../data/http/error";
import { useMarkTargetSetMutation, useUnmarkTargetSetMutation } from "../data/insights/mutation";
import { useSetCompletionQuery } from "../data/insights/query";

export function InsightsPage() {
  const completionQuery = useSetCompletionQuery();
  const markMutation = useMarkTargetSetMutation();
  const unmarkMutation = useUnmarkTargetSetMutation();

  const [newSetCode, setNewSetCode] = createSignal("");
  const [formError, setFormError] = createSignal<string | null>(null);

  const addTargetSet = async () => {
    setFormError(null);
    const setCode = newSetCode().trim();
    if (setCode.length === 0) {
      setFormError("Enter a set code.");
      return;
    }

    try {
      const response = await markMutation.mutateAsync(setCode);
      if (!response.success) {
        setFormError("Could not add set as a target.");
        return;
      }
      setNewSetCode("");
    } catch (error) {
      setFormError(mapError(error).message);
    }
  };

  const removeTargetSet = async (setCode: string) => {
    setFormError(null);
    try {
      await unmarkMutation.mutateAsync(setCode);
    } catch (error) {
      setFormError(mapError(error).message);
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
      <Show when={formError() !== null}>
        <p role="alert">{formError()}</p>
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
                <button
                  onClick={() => removeTargetSet(row.set_code)}
                  disabled={unmarkMutation.isPending}
                >
                  Remove
                </button>
              </li>
            )}
          </For>
        </ul>
      </Show>
    </section>
  );
}
