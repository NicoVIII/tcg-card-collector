import { For, Show, createSignal } from "solid-js";
import { mapError } from "../data/http/error";
import {
  useDeleteInventoryRuleMutation,
  useUpsertInventoryRuleMutation,
} from "../data/inventory_planning/mutation";
import {
  useInventoryProjectionQuery,
  useInventoryRulesQuery,
} from "../data/inventory_planning/query";

export function InventoryPage() {
  const [sortBy, setSortBy] = createSignal("card_name");
  const [groupBy, setGroupBy] = createSignal("location_name");
  const [newRuleName, setNewRuleName] = createSignal("");
  const [newExpression, setNewExpression] = createSignal("set_code=M11");
  const [mutationError, setMutationError] = createSignal<string | null>(null);

  const rulesQuery = useInventoryRulesQuery();
  const projectionQuery = useInventoryProjectionQuery(sortBy, groupBy);
  const upsertMutation = useUpsertInventoryRuleMutation();
  const deleteMutation = useDeleteInventoryRuleMutation();

  const addRule = () => {
    if (newRuleName().trim().length === 0) {
      return;
    }
    setMutationError(null);
    upsertMutation.mutate(
      {
        id: crypto.randomUUID(),
        location_name: newRuleName(),
        expression: newExpression(),
      },
      {
        onError: (error) => setMutationError(mapError(error).message),
      },
    );
  };

  return (
    <section>
      <h2>Inventory</h2>
      <div>
        <label>
          Sort by
          <input value={sortBy()} onInput={(event) => setSortBy(event.currentTarget.value)} />
        </label>
        <label>
          Group by
          <input value={groupBy()} onInput={(event) => setGroupBy(event.currentTarget.value)} />
        </label>
      </div>
      <div>
        <label>
          Location name
          <input
            value={newRuleName()}
            onInput={(event) => setNewRuleName(event.currentTarget.value)}
          />
        </label>
        <label>
          Expression
          <input
            value={newExpression()}
            onInput={(event) => setNewExpression(event.currentTarget.value)}
          />
        </label>
        <button onClick={addRule} disabled={upsertMutation.isPending}>
          Add rule
        </button>
      </div>
      <Show when={mutationError() !== null}>
        <p role="alert">{mutationError()}</p>
      </Show>
      <h3>Rules</h3>
      <Show when={rulesQuery.isLoading}>
        <p>Loading rules...</p>
      </Show>
      <Show when={rulesQuery.isError}>
        <p role="alert">{mapError(rulesQuery.error).message}</p>
      </Show>
      <Show when={(rulesQuery.data?.data?.length ?? 0) > 0} fallback={<p>No rules defined yet.</p>}>
        <ul>
          <For each={rulesQuery.data?.data}>
            {(rule) => (
              <li>
                {rule.location_name}: {rule.expression}
                <button
                  onClick={() =>
                    deleteMutation.mutate(rule.id, {
                      onError: (error) => setMutationError(mapError(error).message),
                    })
                  }
                  disabled={deleteMutation.isPending}
                >
                  Remove
                </button>
              </li>
            )}
          </For>
        </ul>
      </Show>
      <h3>Projection</h3>
      <Show when={projectionQuery.isLoading}>
        <p>Loading projection...</p>
      </Show>
      <Show
        when={(projectionQuery.data?.data?.length ?? 0) > 0}
        fallback={<p>No projection data.</p>}
      >
        <pre>{JSON.stringify(projectionQuery.data, null, 2)}</pre>
      </Show>
    </section>
  );
}
