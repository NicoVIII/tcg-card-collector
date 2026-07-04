import { For, Show, createEffect, createSignal } from "solid-js";
import { mapError } from "../data/http/error";
import {
  useDeleteInventoryRuleMutation,
  useUpdateBulkSpecMutation,
  useUpsertInventoryRuleMutation,
} from "../data/inventory_planning/mutation";
import { SELECTOR_OPTIONS } from "../data/inventory_planning/options";
import {
  useBulkSpecQuery,
  useInventoryProjectionQuery,
  useInventoryRulesQuery,
} from "../data/inventory_planning/query";

export function InventoryPage() {
  const [newRuleName, setNewRuleName] = createSignal("");
  const [newExpression, setNewExpression] = createSignal("set_code=M11");
  const [newPosition, setNewPosition] = createSignal(0);
  const [newSelector, setNewSelector] = createSignal("all");
  const [bulkLocation, setBulkLocation] = createSignal("");
  const [bulkSortKeys, setBulkSortKeys] = createSignal("");
  const [mutationError, setMutationError] = createSignal<string | null>(null);

  const rulesQuery = useInventoryRulesQuery();
  const projectionQuery = useInventoryProjectionQuery();
  const upsertMutation = useUpsertInventoryRuleMutation();
  const deleteMutation = useDeleteInventoryRuleMutation();
  const bulkSpecQuery = useBulkSpecQuery();
  const updateBulkSpecMutation = useUpdateBulkSpecMutation();

  let initializedFromBulkSpec = false;
  createEffect(() => {
    const data = bulkSpecQuery.data;
    if (data !== undefined && !initializedFromBulkSpec) {
      initializedFromBulkSpec = true;
      setBulkLocation(data.location_name);
      setBulkSortKeys(data.sort_keys);
    }
  });

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
        position: newPosition(),
        selector: newSelector(),
      },
      {
        onError: (error) => setMutationError(mapError(error).message),
      },
    );
  };

  const saveBulkSpec = () => {
    setMutationError(null);
    updateBulkSpecMutation.mutate(
      {
        location_name: bulkLocation(),
        sort_keys: bulkSortKeys(),
      },
      {
        onError: (error) => setMutationError(mapError(error).message),
      },
    );
  };

  return (
    <section>
      <h2>Inventory</h2>
      <div class="form-row">
        <label>
          Position
          <input
            type="number"
            value={newPosition()}
            onInput={(event) => setNewPosition(Number(event.currentTarget.value))}
          />
        </label>
        <label>
          Location name
          <input
            value={newRuleName()}
            onInput={(event) => setNewRuleName(event.currentTarget.value)}
          />
        </label>
        <label>
          Selector
          <select
            value={newSelector()}
            onChange={(event) => setNewSelector(event.currentTarget.value)}
          >
            <For each={SELECTOR_OPTIONS}>
              {(option) => <option value={option.value}>{option.label}</option>}
            </For>
          </select>
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
      <p class="hint">
        Location name may fan out with a placeholder: <code>{"{set_code}"}</code>,{" "}
        <code>{"{color_identity}"}</code> or <code>{"{type}"}</code> (e.g.{" "}
        <code>binder {"{color_identity}"}</code>). Rules claim copies in position order.
      </p>
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
              <li class="rule-row">
                #{rule.position} {rule.location_name} [{rule.selector}]: {rule.expression}
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
      <h3>Bulk (leftover cards)</h3>
      <Show when={bulkSpecQuery.isError}>
        <p role="alert">{mapError(bulkSpecQuery.error).message}</p>
      </Show>
      <div class="form-row">
        <label>
          Location name
          <input
            value={bulkLocation()}
            onInput={(event) => setBulkLocation(event.currentTarget.value)}
          />
        </label>
        <label>
          Sort keys
          <input
            value={bulkSortKeys()}
            onInput={(event) => setBulkSortKeys(event.currentTarget.value)}
          />
        </label>
        <button onClick={saveBulkSpec} disabled={updateBulkSpecMutation.isPending}>
          Save bulk
        </button>
      </div>
      <p class="hint">
        Comma-separated sort keys ordering the leftover pile: <code>color_identity</code>,{" "}
        <code>type</code>, <code>name</code>, <code>set_code</code>.
      </p>
      <h3>Projection</h3>
      <Show when={projectionQuery.isLoading}>
        <p>Loading projection...</p>
      </Show>
      <Show when={projectionQuery.isError}>
        <p role="alert">{mapError(projectionQuery.error).message}</p>
      </Show>
      <Show when={(projectionQuery.data?.unknown_count ?? 0) > 0}>
        <p class="hint">
          {projectionQuery.data?.unknown_count} collection card(s) unknown to the catalog — placed
          in bulk without attributes.
        </p>
      </Show>
      <Show
        when={!projectionQuery.isError && (projectionQuery.data?.locations?.length ?? 0) > 0}
        fallback={<p>No projection data.</p>}
      >
        <For each={projectionQuery.data?.locations}>
          {(location) => (
            <div class="projection-location">
              <h4>{location.location_name}</h4>
              <p class="hint">
                {location.rule_id === "" ? "Bulk remainder" : "Rule-assigned"} —{" "}
                {location.total_quantity} card(s)
              </p>
              <table>
                <thead>
                  <tr>
                    <th>Card</th>
                    <th>Set</th>
                    <th>#</th>
                    <th>Qty</th>
                    <th>Color</th>
                    <th>Rarity</th>
                    <th>Type</th>
                  </tr>
                </thead>
                <tbody>
                  <For each={location.cards}>
                    {(card) => (
                      <tr>
                        <td>{card.name}</td>
                        <td>{card.set_code}</td>
                        <td>{card.collector_number}</td>
                        <td>{card.quantity}</td>
                        <td>{card.color_identity}</td>
                        <td>{card.rarity}</td>
                        <td>{card.card_type}</td>
                      </tr>
                    )}
                  </For>
                </tbody>
              </table>
            </div>
          )}
        </For>
      </Show>
    </section>
  );
}
