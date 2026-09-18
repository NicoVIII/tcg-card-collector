import { For, Show, createEffect, createSignal } from "solid-js";
import { ConfirmButton } from "../components/confirm_button";
import { mapError } from "../data/http/error";
import {
  useDeleteInventoryRuleMutation,
  useReorderInventoryRulesMutation,
  useUpdateBulkSpecMutation,
  useUpsertInventoryRuleMutation,
} from "../data/inventory_planning/mutation";
import { SELECTOR_OPTIONS } from "../data/inventory_planning/options";
import { randomUUID } from "../lib/uuid";
import { createMutationError } from "../lib/mutation_error";
import type { InventoryRule, ProjectionLocation } from "../data/inventory_planning/request";
import {
  useBulkSpecQuery,
  useInventoryProjectionQuery,
  useInventoryRulesQuery,
} from "../data/inventory_planning/query";
import {
  applyDraft,
  draftOf,
  emptyDraft,
  isMovable,
  movedOrder,
  nextPosition,
  type RuleDraft,
} from "./inventory_rules";

type RuleFieldsProps = {
  draft: RuleDraft;
  onChange: (draft: RuleDraft) => void;
};

// The four rule fields shared by the add form and each row's edit form.
function RuleFields(props: RuleFieldsProps) {
  const update = (patch: Partial<RuleDraft>) => props.onChange({ ...props.draft, ...patch });

  return (
    <>
      <label>
        Location name
        <input
          value={props.draft.location_name}
          onInput={(event) => update({ location_name: event.currentTarget.value })}
        />
      </label>
      <label>
        Selector
        <select
          value={props.draft.selector}
          onChange={(event) => update({ selector: event.currentTarget.value })}
        >
          <For each={SELECTOR_OPTIONS}>
            {(option) => <option value={option.value}>{option.label}</option>}
          </For>
        </select>
      </label>
      <label>
        Expression
        <input
          value={props.draft.expression}
          onInput={(event) => update({ expression: event.currentTarget.value })}
        />
      </label>
      <label>
        Sort keys
        <input
          value={props.draft.sort_keys}
          onInput={(event) => update({ sort_keys: event.currentTarget.value })}
        />
      </label>
    </>
  );
}

type EditRuleFormProps = {
  rule: InventoryRule;
  onSave: (rule: InventoryRule) => void;
  onCancel: () => void;
  savePending: boolean;
  error: string | null;
};

// Mounted only while its row is open, so the draft seeds from the rule at
// creation — no seed-once effect needed to dodge a background refetch.
function EditRuleForm(props: EditRuleFormProps) {
  // Deliberately read once, not tracked: the draft seeds from whichever rule
  // this form mounted for and never re-seeds itself.
  // eslint-disable-next-line solid/reactivity -- one-time seed by design, see comment above
  const [draft, setDraft] = createSignal<RuleDraft>(draftOf(props.rule));

  return (
    <div class="form-row">
      <RuleFields draft={draft()} onChange={setDraft} />
      <button
        onClick={() => props.onSave(applyDraft(props.rule, draft()))}
        disabled={props.savePending}
      >
        Save
      </button>
      <button type="button" onClick={() => props.onCancel()}>
        Cancel
      </button>
      <Show when={props.error !== null}>
        <p role="alert">{props.error}</p>
      </Show>
    </div>
  );
}

type RuleRowProps = {
  rule: InventoryRule;
  isEditing: boolean;
  canMoveUp: boolean;
  canMoveDown: boolean;
  onEdit: (id: string) => void;
  onCancelEdit: () => void;
  onSave: (rule: InventoryRule) => void;
  onMove: (id: string, offset: -1 | 1) => void;
  onDelete: (id: string) => void;
  savePending: boolean;
  reorderPending: boolean;
  deletePending: boolean;
  editError: string | null;
  deleteError: string | null;
};

function RuleRow(props: RuleRowProps) {
  const panelId = () => `rule-edit-${props.rule.id}`;

  return (
    <li>
      <div class="rule-row">
        <span>
          #{props.rule.position} {props.rule.location_name} [{props.rule.selector}]:{" "}
          {props.rule.expression}
        </span>
        <button
          type="button"
          aria-expanded={props.isEditing}
          aria-controls={panelId()}
          onClick={() => props.onEdit(props.rule.id)}
        >
          Edit
        </button>
        <button
          type="button"
          aria-label={`Move ${props.rule.location_name} up`}
          onClick={() => props.onMove(props.rule.id, -1)}
          disabled={!props.canMoveUp || props.reorderPending}
        >
          ▲
        </button>
        <button
          type="button"
          aria-label={`Move ${props.rule.location_name} down`}
          onClick={() => props.onMove(props.rule.id, 1)}
          disabled={!props.canMoveDown || props.reorderPending}
        >
          ▼
        </button>
        <ConfirmButton
          label="Remove"
          ariaLabel={`Remove rule for ${props.rule.location_name}`}
          disabled={props.deletePending}
          onConfirm={() => props.onDelete(props.rule.id)}
        />
      </div>
      <Show when={props.deleteError !== null}>
        <p role="alert">{props.deleteError}</p>
      </Show>
      <Show when={props.isEditing}>
        <div id={panelId()}>
          <EditRuleForm
            rule={props.rule}
            onSave={props.onSave}
            onCancel={props.onCancelEdit}
            savePending={props.savePending}
            error={props.editError}
          />
        </div>
      </Show>
    </li>
  );
}

type AddRuleFormProps = {
  draft: RuleDraft;
  onChange: (draft: RuleDraft) => void;
  onAdd: () => void;
  pending: boolean;
  error: string | null;
};

function AddRuleForm(props: AddRuleFormProps) {
  return (
    <div class="form-row">
      <RuleFields draft={props.draft} onChange={props.onChange} />
      <button onClick={() => props.onAdd()} disabled={props.pending}>
        Add rule
      </button>
      <Show when={props.error !== null}>
        <p role="alert">{props.error}</p>
      </Show>
    </div>
  );
}

function ProjectionLocationTable(props: { location: ProjectionLocation }) {
  return (
    <div class="projection-location">
      <h4>{props.location.location_name}</h4>
      <p class="hint">
        {props.location.rule_id === "" ? "Bulk remainder" : "Rule-assigned"} —{" "}
        {props.location.total_quantity} card(s)
      </p>
      <table>
        <thead>
          <tr>
            <th>Card</th>
            <th>Set</th>
            <th>#</th>
            <th>Finish</th>
            <th>Lang</th>
            <th>Qty</th>
            <th>Color</th>
            <th>Rarity</th>
            <th>Type</th>
          </tr>
        </thead>
        <tbody>
          <For each={props.location.cards}>
            {(card) => (
              <tr>
                <td>{card.name}</td>
                <td>{card.set_code}</td>
                <td>{card.collector_number}</td>
                <td>{card.finish}</td>
                <td>{card.language}</td>
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
  );
}

function ProjectionSection() {
  const projectionQuery = useInventoryProjectionQuery();
  const unknownCount = () => projectionQuery.data?.unknown_count ?? 0;
  const locations = () => projectionQuery.data?.locations ?? [];

  return (
    <>
      <h3>Projection</h3>
      <Show when={projectionQuery.isLoading}>
        <p>Loading projection...</p>
      </Show>
      <Show when={projectionQuery.isError}>
        <p role="alert">{mapError(projectionQuery.error).message}</p>
      </Show>
      <Show when={unknownCount() > 0}>
        <p class="hint">
          {unknownCount()} collection card(s) unknown to the catalog — placed in bulk without
          attributes.
        </p>
      </Show>
      <Show
        when={!projectionQuery.isError && locations().length > 0}
        fallback={<p>No projection data.</p>}
      >
        <For each={locations()}>
          {(location) => <ProjectionLocationTable location={location} />}
        </For>
      </Show>
    </>
  );
}

export function InventoryPage() {
  const [newRuleDraft, setNewRuleDraft] = createSignal<RuleDraft>(emptyDraft());
  const [editingId, setEditingId] = createSignal<string | null>(null);
  const [bulkLocation, setBulkLocation] = createSignal("");
  const [bulkSortKeys, setBulkSortKeys] = createSignal("");
  const mutationError = createMutationError();

  const rulesQuery = useInventoryRulesQuery();
  const upsertMutation = useUpsertInventoryRuleMutation();
  const deleteMutation = useDeleteInventoryRuleMutation();
  const reorderMutation = useReorderInventoryRulesMutation();
  const bulkSpecQuery = useBulkSpecQuery();
  const updateBulkSpecMutation = useUpdateBulkSpecMutation();

  const rules = () => rulesQuery.data?.data ?? [];

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
    mutationError.clear();
    const draft = newRuleDraft();
    if (draft.location_name.trim().length === 0) {
      mutationError.report(new Error("Enter a location name for the rule."), "add");
      return;
    }
    upsertMutation.mutate(
      { id: randomUUID(), position: nextPosition(rules()), ...draft },
      {
        onSuccess: () => setNewRuleDraft(emptyDraft()),
        onError: (error) => mutationError.report(error, "add"),
      },
    );
  };

  const editRule = (id: string) => {
    mutationError.clear();
    setEditingId(id);
  };

  const cancelEdit = () => {
    mutationError.clear();
    setEditingId(null);
  };

  const saveRule = (rule: InventoryRule) => {
    mutationError.clear();
    upsertMutation.mutate(rule, {
      onSuccess: () => setEditingId(null),
      onError: (error) => mutationError.report(error, rule.id),
    });
  };

  const moveRule = (id: string, offset: -1 | 1) => {
    if (!isMovable(rules(), id, offset)) {
      return;
    }
    mutationError.clear();
    reorderMutation.mutate(movedOrder(rules(), id, offset), {
      onError: (error) => mutationError.report(error, "reorder"),
    });
  };

  const removeRule = (id: string) => {
    mutationError.clear();
    deleteMutation.mutate(id, {
      onError: (error) => mutationError.report(error, `delete:${id}`),
    });
  };

  const saveBulkSpec = () => {
    mutationError.clear();
    updateBulkSpecMutation.mutate(
      {
        location_name: bulkLocation(),
        sort_keys: bulkSortKeys(),
      },
      {
        onError: (error) => mutationError.report(error, "bulk"),
      },
    );
  };

  return (
    <section>
      <h2>Inventory</h2>
      <AddRuleForm
        draft={newRuleDraft()}
        onChange={setNewRuleDraft}
        onAdd={addRule}
        pending={upsertMutation.isPending}
        error={mutationError.messageFor("add")}
      />
      {/* These hints restate the DSL grammar owned by the parsers in
          server/src/inventory_planning/domain/ — keep them in sync. */}
      <p class="hint">
        Location name may fan out with a placeholder: <code>{"{set_code}"}</code>,{" "}
        <code>{"{set_family}"}</code>, <code>{"{color_identity}"}</code> or <code>{"{type}"}</code>{" "}
        (e.g. <code>binder {"{color_identity}"}</code>). Rules claim copies in the list order below
        — use ▲/▼ to reorder them. Fanned locations are ordered by set release date, color (WUBRG
        mono, then multicolor in WOTC's printed order, then colorless), or type rank (land first)
        respectively. <code>{"{set_family}"}</code> groups a set with its token/promo child sets
        under the parent's binder — parent-set cards first, child-set cards after — and orders those
        binders by the parent set's release date.
      </p>
      <p class="hint">
        Expression is one or more conditions joined by <code>and</code>:{" "}
        <code>set_code in (grn, m19)</code>, <code>rarity {">"}= rare</code>,{" "}
        <code>rarity in (common, uncommon)</code>, <code>color_identity = WU</code> (or{" "}
        <code>colorless</code>), <code>type = creature</code>, <code>finish = foil</code> (or{" "}
        <code>finish in (foil, etched)</code>) — e.g.{" "}
        <code>set_code in (grn, m19) and rarity {">"}= rare</code>.
      </p>
      <p class="hint">
        Sort keys are a comma-separated list ordering the cards within each location:{" "}
        <code>color_identity</code>, <code>type</code>, <code>name</code>, <code>set_code</code>,{" "}
        <code>collector_number</code>, <code>rarity</code>, <code>released_at</code>,{" "}
        <code>cmc</code>. Empty keeps the canonical order (release date, set, collector number).
      </p>
      <Show when={mutationError.messageFor("reorder") !== null}>
        <p role="alert">{mutationError.messageFor("reorder")}</p>
      </Show>
      <h3>Rules</h3>
      <Show when={rulesQuery.isLoading}>
        <p>Loading rules...</p>
      </Show>
      <Show when={rulesQuery.isError}>
        <p role="alert">{mapError(rulesQuery.error).message}</p>
      </Show>
      <Show when={rules().length > 0} fallback={<p>No rules defined yet.</p>}>
        <ul>
          <For each={rules()}>
            {(rule) => (
              <RuleRow
                rule={rule}
                isEditing={editingId() === rule.id}
                canMoveUp={isMovable(rules(), rule.id, -1)}
                canMoveDown={isMovable(rules(), rule.id, 1)}
                onEdit={editRule}
                onCancelEdit={cancelEdit}
                onSave={saveRule}
                onMove={moveRule}
                onDelete={removeRule}
                savePending={upsertMutation.isPending}
                reorderPending={reorderMutation.isPending}
                deletePending={deleteMutation.isPending}
                editError={mutationError.messageFor(rule.id)}
                deleteError={mutationError.messageFor(`delete:${rule.id}`)}
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
      <Show when={mutationError.messageFor("bulk") !== null}>
        <p role="alert">{mutationError.messageFor("bulk")}</p>
      </Show>
      <p class="hint">
        Comma-separated sort keys ordering the leftover pile: <code>color_identity</code>,{" "}
        <code>type</code>, <code>name</code>, <code>set_code</code>, <code>collector_number</code>,{" "}
        <code>rarity</code>, <code>released_at</code>, <code>cmc</code>.
      </p>
      <ProjectionSection />
    </section>
  );
}
