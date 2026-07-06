import { For, Show, createEffect, createSignal } from "solid-js";
import { mapError } from "../data/http/error";
import {
  useDeleteInventoryRuleMutation,
  useUpdateBulkSpecMutation,
  useUpsertInventoryRuleMutation,
} from "../data/inventory_planning/mutation";
import { SELECTOR_OPTIONS } from "../data/inventory_planning/options";
import type { InventoryRule } from "../data/inventory_planning/request";
import {
  useBulkSpecQuery,
  useInventoryProjectionQuery,
  useInventoryRulesQuery,
} from "../data/inventory_planning/query";

type RuleRowProps = {
  rule: InventoryRule;
  onSave: (rule: InventoryRule) => void;
  onDelete: (id: string) => void;
  savePending: boolean;
  deletePending: boolean;
};

// A rule row owns a local copy of its sort keys, seeded once from the prop, so a
// background refetch of the rules list can't clobber an in-progress edit.
function RuleRow(props: RuleRowProps) {
  const [sortKeys, setSortKeys] = createSignal("");

  let initialized = false;
  createEffect(() => {
    const value = props.rule.sort_keys;
    if (!initialized) {
      initialized = true;
      setSortKeys(value);
    }
  });

  return (
    <li class="rule-row">
      #{props.rule.position} {props.rule.location_name} [{props.rule.selector}]:{" "}
      {props.rule.expression}
      <label>
        Sort keys
        <input value={sortKeys()} onInput={(event) => setSortKeys(event.currentTarget.value)} />
      </label>
      <button
        onClick={() => props.onSave({ ...props.rule, sort_keys: sortKeys() })}
        disabled={props.savePending}
      >
        Save
      </button>
      <button onClick={() => props.onDelete(props.rule.id)} disabled={props.deletePending}>
        Remove
      </button>
    </li>
  );
}

export function InventoryPage() {
  const [newRuleName, setNewRuleName] = createSignal("");
  const [newExpression, setNewExpression] = createSignal("set_code in (m11)");
  const [newPosition, setNewPosition] = createSignal(0);
  const [newSelector, setNewSelector] = createSignal("all");
  const [newSortKeys, setNewSortKeys] = createSignal("");
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
        sort_keys: newSortKeys(),
      },
      {
        onError: (error) => setMutationError(mapError(error).message),
      },
    );
  };

  const saveRule = (rule: InventoryRule) => {
    setMutationError(null);
    upsertMutation.mutate(rule, {
      onError: (error) => setMutationError(mapError(error).message),
    });
  };

  const removeRule = (id: string) => {
    deleteMutation.mutate(id, {
      onError: (error) => setMutationError(mapError(error).message),
    });
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
        <label>
          Sort keys
          <input
            value={newSortKeys()}
            onInput={(event) => setNewSortKeys(event.currentTarget.value)}
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
      <p class="hint">
        Expression is one or more conditions joined by <code>and</code>:{" "}
        <code>set_code in (grn, m19)</code>, <code>rarity {">"}= rare</code>,{" "}
        <code>rarity in (common, uncommon)</code>, <code>color_identity = WU</code> (or{" "}
        <code>colorless</code>), <code>type = creature</code> — e.g.{" "}
        <code>set_code in (grn, m19) and rarity {">"}= rare</code>.
      </p>
      <p class="hint">
        Sort keys are a comma-separated list ordering the cards within each location:{" "}
        <code>color_identity</code>, <code>type</code>, <code>name</code>, <code>set_code</code>,{" "}
        <code>collector_number</code>, <code>rarity</code>, <code>released_at</code>. Empty keeps
        the canonical order (release date, set, collector number).
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
              <RuleRow
                rule={rule}
                onSave={saveRule}
                onDelete={removeRule}
                savePending={upsertMutation.isPending}
                deletePending={deleteMutation.isPending}
              />
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
        <code>type</code>, <code>name</code>, <code>set_code</code>, <code>collector_number</code>,{" "}
        <code>rarity</code>, <code>released_at</code>.
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
