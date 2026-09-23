import { For, Show, createEffect, createMemo, createSignal } from "solid-js";
import { useSearchParams } from "@solidjs/router";
import { ConfirmButton } from "../components/confirm_button";
import { CardSearchForm } from "../components/card_search_form";
import { Pagination } from "../components/pagination";
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
import {
  filterFromSearchParams,
  searchParamsFromFilter,
  type CardFilter,
} from "../lib/card_filter";
import type { InventoryRule, ProjectionCard } from "../data/inventory_planning/request";
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
import { focusNameFrom } from "./placement_focus";
import {
  PROJECTION_PAGE_SIZE,
  countLabel,
  filterIsActive,
  openLocationCards,
  projectionSummaries,
  type ProjectionLocationSummary,
} from "./inventory_projection";

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

function ProjectionCardsTable(props: { cards: ProjectionCard[] }) {
  return (
    <div class="table-scroll">
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
          <For each={props.cards}>
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

type ProjectionLocationPanelProps = {
  cards: ProjectionCard[];
  offset: number;
  onOffsetChange: (offset: number) => void;
};

function ProjectionLocationPanel(props: ProjectionLocationPanelProps) {
  // Clamped to the last full page rather than trusted as-is: a browser
  // back/forward step can restore an old `?location=` without passing
  // through `toggle`'s reset, and a new search can shrink the filtered list
  // out from under a deep offset — this keeps the panel on a real page
  // instead of a blank or single-row one.
  const maxOffset = () =>
    Math.floor(Math.max(0, props.cards.length - 1) / PROJECTION_PAGE_SIZE) * PROJECTION_PAGE_SIZE;
  const offset = () => Math.min(props.offset, maxOffset());
  const page = () => props.cards.slice(offset(), offset() + PROJECTION_PAGE_SIZE);

  return (
    <>
      <Show when={props.cards.length > PROJECTION_PAGE_SIZE}>
        <Pagination
          offset={offset()}
          limit={PROJECTION_PAGE_SIZE}
          total={props.cards.length}
          onOffsetChange={props.onOffsetChange}
        />
      </Show>
      <ProjectionCardsTable cards={page()} />
    </>
  );
}

type ProjectionLocationRowProps = {
  summary: ProjectionLocationSummary;
  filterActive: boolean;
  panelId: string;
  isOpen: boolean;
  cards: ProjectionCard[] | null;
  offset: number;
  onOffsetChange: (offset: number) => void;
  onToggle: (location_name: string, headerEl: HTMLElement) => void;
};

function ProjectionLocationRow(props: ProjectionLocationRowProps) {
  let headerRef: HTMLButtonElement | undefined;

  return (
    <div class="placement-location">
      <h4 class="placement-location-header">
        <button
          ref={(element) => {
            headerRef = element;
          }}
          type="button"
          class="placement-location-toggle"
          aria-expanded={props.isOpen}
          aria-controls={props.panelId}
          onClick={() => headerRef && props.onToggle(props.summary.location_name, headerRef)}
        >
          <span aria-hidden="true">{props.isOpen ? "▾" : "▸"}</span>
          <span>
            {props.summary.location_name}
            {props.summary.is_bulk ? " (bulk remainder)" : ""}
          </span>
          <span>{countLabel(props.summary, props.filterActive)}</span>
        </button>
      </h4>
      <Show when={props.isOpen && props.cards !== null}>
        <div id={props.panelId}>
          <ProjectionLocationPanel
            cards={props.cards as ProjectionCard[]}
            offset={props.offset}
            onOffsetChange={props.onOffsetChange}
          />
        </div>
      </Show>
    </div>
  );
}

function ProjectionSection() {
  const projectionQuery = useInventoryProjectionQuery();
  const [searchParams, setSearchParams] = useSearchParams<{
    location?: string;
    name?: string;
    set?: string;
  }>();
  const filter = createMemo<CardFilter>(() => filterFromSearchParams(searchParams));
  const filterActive = createMemo(() => filterIsActive(filter()));
  const openName = () => focusNameFrom(searchParams.location);
  // Owned here (not per-panel) so opening a different location or running a
  // new search can reset it directly, the same way collection_page.tsx's
  // `search` calls `setOffset(0)` alongside `setSearchParams` — no effect
  // needed to notice the change after the fact.
  const [offset, setOffset] = createSignal(0);

  const unknownCount = () => projectionQuery.data?.unknown_count ?? 0;
  const summaries = createMemo(() => projectionSummaries(projectionQuery.data, filter()));
  const openCards = createMemo(() => openLocationCards(projectionQuery.data, openName(), filter()));

  const search = (next: CardFilter) => {
    setOffset(0);
    setSearchParams({ location: searchParams.location, ...searchParamsFromFilter(next) });
  };

  // A history entry per open/close (not a replace), mirroring
  // placement_page.tsx's toggleFocus — back-to-close is the phone affordance
  // alongside re-tapping the header.
  const toggle = (location_name: string, headerEl: HTMLElement) => {
    setOffset(0);
    setSearchParams({ location: openName() === location_name ? undefined : location_name });
    headerEl.scrollIntoView({ block: "nearest" });
  };

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
      <CardSearchForm filter={filter()} onSearch={search} />
      <Show
        when={!projectionQuery.isError && summaries().length > 0}
        fallback={<p>{filterActive() ? "No projected cards match." : "No projection data."}</p>}
      >
        <For each={summaries()}>
          {(summary, index) => (
            <ProjectionLocationRow
              summary={summary}
              filterActive={filterActive()}
              panelId={`projection-panel-${index()}`}
              isOpen={openName() === summary.location_name}
              cards={openName() === summary.location_name ? openCards() : null}
              offset={offset()}
              onOffsetChange={setOffset}
              onToggle={toggle}
            />
          )}
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
        Selector decides how many copies a rule claims: every copy, the first copy per printing, or
        the first copy per card — one per oracle identity, however many printings of it you own.
        Where several of your copies qualify, the earliest in canonical order wins: language
        (English, then by code), then finish (etched, foil, nonfoil), then release date (oldest
        first, unknown dates before all others), then set code, then collector number. Language and
        finish come before release date, so a first-copy rule claims your best copy of a card, not
        its oldest printing.
      </p>
      <p class="hint">
        Expression is one or more conditions joined by <code>and</code>:{" "}
        <code>set_code in (grn, m19)</code>, <code>rarity {">"}= rare</code>,{" "}
        <code>rarity in (common, uncommon)</code>, <code>color_identity = WU</code> (or{" "}
        <code>colorless</code>), <code>type = creature</code>, <code>finish = foil</code> (or{" "}
        <code>finish in (foil, etched)</code>) — e.g.{" "}
        <code>set_code in (grn, m19) and rarity {">"}= rare</code>. Any of <code>set_code</code>,{" "}
        <code>color_identity</code>, <code>type</code>, <code>finish</code> also takes{" "}
        <code>!=</code> instead of <code>=</code>, e.g. <code>finish != foil</code>.{" "}
        <code>language = de</code> (or <code>language in (de, fr)</code>,{" "}
        <code>language != en</code>) matches printed language — e.g. <code>language != en</code>{" "}
        routes every non-English copy.
      </p>
      <p class="hint">
        Sort keys are a comma-separated list ordering the cards within each location:{" "}
        <code>color_identity</code>, <code>type</code>, <code>name</code>, <code>set_code</code>,{" "}
        <code>collector_number</code>, <code>rarity</code>, <code>released_at</code>,{" "}
        <code>cmc</code>, <code>language</code> (English first, then by code). Empty keeps the
        canonical order described above. Sort keys only order what a location shows — which copy a
        rule claims is the selector's business.
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
        <code>rarity</code>, <code>released_at</code>, <code>cmc</code>, <code>language</code>.
      </p>
      <ProjectionSection />
    </section>
  );
}
