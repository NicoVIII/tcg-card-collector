import { createSignal } from "solid-js";
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
  const [groupBy, setGroupBy] = createSignal("location");
  const [ruleName, setRuleName] = createSignal("main-binder");

  const rulesQuery = useInventoryRulesQuery();
  const projectionQuery = useInventoryProjectionQuery(sortBy, groupBy);
  const upsertMutation = useUpsertInventoryRuleMutation();
  const deleteMutation = useDeleteInventoryRuleMutation();

  return (
    <section>
      <h2>Inventory</h2>
      <div>
        <input value={sortBy()} onInput={(event) => setSortBy(event.currentTarget.value)} />
        <input value={groupBy()} onInput={(event) => setGroupBy(event.currentTarget.value)} />
      </div>
      <div>
        <input value={ruleName()} onInput={(event) => setRuleName(event.currentTarget.value)} />
        <button
          onClick={() =>
            upsertMutation.mutate({
              id: crypto.randomUUID(),
              location_name: ruleName(),
              expression: "set_code=M11",
            })
          }
          disabled={upsertMutation.isPending}
        >
          Upsert rule
        </button>
        <button
          onClick={() => deleteMutation.mutate(ruleName())}
          disabled={deleteMutation.isPending}
        >
          Delete rule by id
        </button>
      </div>
      <h3>Rules</h3>
      <pre>{JSON.stringify(rulesQuery.data, null, 2)}</pre>
      <h3>Projection</h3>
      <pre>{JSON.stringify(projectionQuery.data, null, 2)}</pre>
    </section>
  );
}
