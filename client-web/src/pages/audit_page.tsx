import { For, Show, createEffect, createMemo, createSignal, untrack } from "solid-js";
import { A, useSearchParams } from "@solidjs/router";
import { useCardQuery } from "../data/card_catalog/query";
import { copyIdentityKey, type CopyIdentity } from "../data/collection/copy_kind";
import { mapError } from "../data/http/error";
import { useInventoryProjectionQuery } from "../data/inventory_planning/query";
import {
  locationKey,
  parseLocationKey,
  type LocationRef,
} from "../data/inventory_planning/location_ref";
import type { InventoryProjection } from "../data/inventory_planning/request";
import {
  type AuditRow,
  type AuditableLocation,
  type SourceCandidate,
  auditableLocations,
  buildAuditRows,
  ownedQuantities,
  placedTotal,
  sourceCandidates,
} from "../data/location_audit/audit_list";
import {
  type AuditSession,
  type UnexpectedFind,
  addUnexpected,
  emptyAuditSession,
  foundCount,
  missingRows,
  removeUnexpected,
  reportOnly,
  restoreSession,
  serializeSession,
  setFound,
  setUnexpectedSource,
  toRequest,
  unresolvedCopies,
} from "../data/location_audit/audit_session";
import { clearDraft, hasDraft, loadDraft, saveDraft } from "../data/location_audit/draft_storage";
import { useCompleteLocationAuditMutation } from "../data/location_audit/mutation";
import { useLocationAuditsQuery } from "../data/location_audit/query";
import type { LocationAuditSummary } from "../data/location_audit/request";
import type { PlacedLedgerRow } from "../data/placement/request";
import { usePlacedLedgerQuery } from "../data/placement/query";
import { ConfirmButton } from "../components/confirm_button";
import { CopyEntryForm, type RawCopyEntry } from "../components/copy_entry_form";
import { createMutationError } from "../lib/mutation_error";
import { normalizeEntry } from "./add_cards_staging";

function copyLabel(copy: CopyIdentity): string {
  return `${copy.set_code} ${copy.collector_number} (${copy.finish}·${copy.language})`;
}

function lastAuditedLabel(audits: LocationAuditSummary[], location: LocationRef): string {
  const audit = audits.find((entry) => locationKey(entry.location) === locationKey(location));
  return audit === undefined ? "never" : new Date(audit.last_audited_at).toLocaleString();
}

function LocationList(props: {
  locations: AuditableLocation[];
  audits: LocationAuditSummary[];
  onOpen: (location: LocationRef) => void;
}) {
  return (
    <ul class="placement-list">
      <For each={props.locations}>
        {(entry) => (
          <li class="placement-row">
            <span class="placement-card">
              <strong>{entry.location_name}</strong>
              <span class="placement-card-key">{entry.recorded_total} recorded</span>
              <span class="placement-card-hint">
                last audited {lastAuditedLabel(props.audits, entry.location)}
                {hasDraft(entry.location) ? " · walk in progress" : ""}
              </span>
            </span>
            <button
              type="button"
              class="placement-mark-through"
              aria-label={`Audit ${entry.location_name}`}
              onClick={() => props.onOpen(entry.location)}
            >
              {hasDraft(entry.location) ? "Resume" : "Audit"}
            </button>
          </li>
        )}
      </For>
    </ul>
  );
}

function AuditRowItem(props: { row: AuditRow; found: number; onSet: (count: number) => void }) {
  const label = () => props.row.name || copyLabel(props.row);
  return (
    <li
      class="placement-row"
      classList={{ "placement-row-done": props.found === props.row.recorded }}
    >
      <span class="placement-card">
        <span class="placement-card-name">{props.row.name || "Unknown card"}</span>
        <span class="placement-card-key">{copyLabel(props.row)}</span>
        <span>
          found {props.found} of {props.row.recorded}
        </span>
      </span>
      <span class="audit-controls">
        <button
          type="button"
          aria-label={`One fewer ${label()} found`}
          disabled={props.found === 0}
          onClick={() => props.onSet(props.found - 1)}
        >
          −
        </button>
        <button
          type="button"
          aria-label={`One more ${label()} found`}
          disabled={props.found === props.row.recorded}
          onClick={() => props.onSet(props.found + 1)}
        >
          +
        </button>
        <button
          type="button"
          aria-label={`All ${props.row.recorded} ${label()} found`}
          disabled={props.found === props.row.recorded}
          onClick={() => props.onSet(props.row.recorded)}
        >
          All
        </button>
      </span>
    </li>
  );
}

// #155's lesson: a failed lookup is not "not in the catalog".
function CatalogName(props: { copy: CopyIdentity }) {
  const cardQuery = useCardQuery(() => ({
    set_code: props.copy.set_code,
    collector_number: props.copy.collector_number,
  }));
  const text = () => {
    if (cardQuery.isLoading) return "Looking up…";
    if (cardQuery.isError) return `Catalog lookup failed: ${mapError(cardQuery.error).message}`;
    return cardQuery.data?.name ?? "Unknown card (not in catalog)";
  };
  return <span class="staging-name">{text()}</span>;
}

function SourcePicker(props: {
  find: UnexpectedFind;
  candidates: SourceCandidate[];
  onSource: (source: LocationRef | null) => void;
}) {
  return (
    <label>
      Came from
      <select
        value={props.find.source === null ? "" : locationKey(props.find.source)}
        onChange={(event) => props.onSource(parseLocationKey(event.currentTarget.value))}
      >
        <option value="">nowhere recorded</option>
        <For each={props.candidates}>
          {(candidate) => (
            <option value={locationKey(candidate.location)}>
              {candidate.location_name} ({candidate.quantity} recorded)
            </option>
          )}
        </For>
      </select>
    </label>
  );
}

function UnexpectedItem(props: {
  find: UnexpectedFind;
  candidates: SourceCandidate[];
  unresolved: boolean;
  onSource: (source: LocationRef | null) => void;
  onRemove: () => void;
}) {
  return (
    <li class="staging-row audit-find">
      <span class="staging-key">
        {props.find.quantity}x {copyLabel(props.find.copy)}
      </span>
      <CatalogName copy={props.find.copy} />
      <Show
        when={props.find.in_collection}
        fallback={
          <span class="hint">
            Not in your collection: nothing is recorded for it. Add it via{" "}
            <A href="/collection">Collection</A>.
          </span>
        }
      >
        <Show when={props.candidates.length > 0}>
          <SourcePicker find={props.find} candidates={props.candidates} onSource={props.onSource} />
        </Show>
        <Show when={props.unresolved}>
          <span class="staging-over" role="alert">
            Every owned copy is already recorded somewhere: say where this one came from.
          </span>
        </Show>
      </Show>
      <button
        type="button"
        class="staging-remove"
        aria-label={`Remove found ${copyLabel(props.find.copy)}`}
        onClick={() => props.onRemove()}
      >
        ✕
      </button>
    </li>
  );
}

type WalkContext = {
  location: LocationRef;
  location_name: string;
  rows: AuditRow[];
  ledger: PlacedLedgerRow[];
  owned: Map<string, number>;
  locations: AuditableLocation[];
};

function initialSession(context: WalkContext): { session: AuditSession; notice: string | null } {
  const raw = loadDraft(context.location);
  if (raw === null) {
    return { session: emptyAuditSession(), notice: null };
  }
  const outcome = restoreSession(raw, context.rows);
  if (outcome.kind === "restored") {
    return { session: outcome.session, notice: "Resumed the walk saved in this browser." };
  }
  clearDraft(context.location);
  return {
    session: emptyAuditSession(),
    notice:
      outcome.kind === "stale"
        ? "The saved walk no longer matched what's recorded here, so it was dropped. Start again."
        : "The saved walk couldn't be read, so it was dropped. Start again.",
  };
}

// A source is pre-selected when the find can't be marked without one and
// exactly one other location records the copy (ADR 0024).
function defaultSource(
  copy: CopyIdentity,
  quantity: number,
  context: WalkContext,
): LocationRef | null {
  const available =
    (context.owned.get(copyIdentityKey(copy)) ?? 0) - placedTotal(context.ledger, copy);
  const candidates = sourceCandidates(copy, context.location, context.ledger, context.locations);
  return quantity > available && candidates.length === 1 ? candidates[0].location : null;
}

function toFind(entry: RawCopyEntry, context: WalkContext): UnexpectedFind | null {
  const staged = normalizeEntry(entry);
  if (staged === null) {
    return null;
  }
  const copy: CopyIdentity = {
    set_code: staged.setCode,
    collector_number: staged.collectorNumber,
    finish: staged.finish,
    language: staged.language,
  };
  return {
    copy,
    quantity: staged.quantity,
    in_collection: (context.owned.get(copyIdentityKey(copy)) ?? 0) > 0,
    source: defaultSource(copy, staged.quantity, context),
  };
}

function AuditWalk(props: { context: WalkContext; onDone: (note: string) => void }) {
  // eslint-disable-next-line solid/reactivity -- read once: the page mounts a fresh walk per context (a keyed <Show>), and a restored draft seeds the session only at mount
  const start = initialSession(props.context);
  const [session, setSession] = createSignal(start.session);
  const [notice, setNotice] = createSignal(start.notice);
  const [entryError, setEntryError] = createSignal<string | null>(null);
  const mutationError = createMutationError();
  const completeMutation = useCompleteLocationAuditMutation();

  createEffect(() => {
    const current = session();
    if (current.found.size === 0 && current.unexpected.length === 0) {
      clearDraft(props.context.location);
      return;
    }
    if (!saveDraft(props.context.location, serializeSession(current))) {
      setNotice("This browser can't save the walk, so a reload will lose it.");
    }
  });

  const unresolved = createMemo(() =>
    unresolvedCopies(session(), props.context.owned, props.context.ledger),
  );
  const missingTotal = () =>
    missingRows(session(), props.context.rows).reduce((sum, row) => sum + row.recorded, 0);

  const addFind = (entry: RawCopyEntry): boolean => {
    const find = toFind(entry, props.context);
    if (find === null) {
      setEntryError("Enter a set code, a collector number, and a quantity of at least 1.");
      return false;
    }
    setEntryError(null);
    setSession((current) => addUnexpected(current, find));
    return true;
  };

  const abandon = () => {
    clearDraft(props.context.location);
    props.onDone(`Abandoned the audit of ${props.context.location_name}; nothing was changed.`);
  };

  const complete = () => {
    mutationError.clear();
    completeMutation.mutate(toRequest(props.context.location, session(), props.context.rows), {
      onSuccess: () => {
        clearDraft(props.context.location);
        props.onDone(`Audit of ${props.context.location_name} completed.`);
      },
      onError: (error) => mutationError.report(error),
    });
  };

  return (
    <section class="placement-location">
      <h3>Auditing {props.context.location_name}</h3>
      <p class="hint">
        Walk the location and count what you find for each card. Cards you find that aren't listed
        go under "Found but not listed". Nothing is saved to your records until you complete the
        audit; anything not found then comes off this location and shows up again under Place cards.
      </p>
      <Show when={notice()}>
        <p class="hint" role="status">
          {notice()}
        </p>
      </Show>
      <Show
        when={props.context.rows.length > 0}
        fallback={<p>Nothing is recorded at this location.</p>}
      >
        <ul class="placement-list">
          <For each={props.context.rows}>
            {(row) => (
              <AuditRowItem
                row={row}
                found={foundCount(session(), row)}
                onSet={(count) => setSession((current) => setFound(current, row, count))}
              />
            )}
          </For>
        </ul>
      </Show>
      <h3>Found but not listed</h3>
      <CopyEntryForm submitLabel="Add found card" onSubmit={addFind} />
      <Show when={entryError()}>
        <p role="alert">{entryError()}</p>
      </Show>
      <ul class="staging-list">
        <For each={session().unexpected}>
          {(find, index) => (
            <UnexpectedItem
              find={find}
              candidates={sourceCandidates(
                find.copy,
                props.context.location,
                props.context.ledger,
                props.context.locations,
              )}
              unresolved={unresolved().has(copyIdentityKey(find.copy))}
              onSource={(source) =>
                setSession((current) => setUnexpectedSource(current, index(), source))
              }
              onRemove={() => setSession((current) => removeUnexpected(current, index()))}
            />
          )}
        </For>
      </ul>
      <p class="hint">
        {missingTotal()} card(s) not found will come off this location.
        {reportOnly(session()).length > 0
          ? ` ${reportOnly(session()).length} found card(s) aren't in your collection and won't be recorded.`
          : ""}
      </p>
      <Show when={mutationError.messageFor() !== null}>
        <p role="alert">{mutationError.messageFor()}</p>
      </Show>
      <div class="form-row">
        <ConfirmButton
          label="Complete audit"
          disabled={completeMutation.isPending || unresolved().size > 0}
          onConfirm={complete}
        />
        <ConfirmButton
          label="Abandon"
          ariaLabel={`Abandon the audit of ${props.context.location_name}`}
          disabled={completeMutation.isPending}
          onConfirm={abandon}
        />
      </div>
    </section>
  );
}

function walkContext(
  location: LocationRef,
  projection: InventoryProjection,
  ledger: PlacedLedgerRow[],
): WalkContext | null {
  const locations = auditableLocations(projection, ledger);
  const entry = locations.find(
    (candidate) => locationKey(candidate.location) === locationKey(location),
  );
  if (entry === undefined) {
    return null;
  }
  return {
    location,
    location_name: entry.location_name,
    rows: buildAuditRows(location, projection, ledger),
    ledger,
    owned: ownedQuantities(projection),
    locations,
  };
}

// Walking a location to check the placed ledger against what is physically
// there (#108, ADR 0024). Off the main nav; reached from Place cards.
export function AuditPage() {
  const [searchParams, setSearchParams] = useSearchParams<{ location?: string }>();
  const projectionQuery = useInventoryProjectionQuery();
  const ledgerQuery = usePlacedLedgerQuery();
  const auditsQuery = useLocationAuditsQuery();
  const [note, setNote] = createSignal<string | null>(null);

  const loadError = () => projectionQuery.error ?? ledgerQuery.error ?? auditsQuery.error;
  // Memoized so a refetch that replaces the data, but not its presence,
  // doesn't notify the walk's memo below.
  const ready = createMemo(
    () =>
      projectionQuery.data !== undefined &&
      ledgerQuery.data !== undefined &&
      auditsQuery.data !== undefined,
  );
  const openLocation = () =>
    searchParams.location === undefined ? null : parseLocationKey(searchParams.location);
  // A walk is built once per opened location from the data as it stood then:
  // completing refetches the ledger, and rebuilding on that would remount the
  // walk before its completion handler ran. A reload re-validates the saved
  // draft against the fresh ledger instead (restoreSession).
  const context = createMemo(() => {
    const location = openLocation();
    if (location === null || !ready()) {
      return null;
    }
    return untrack(() => walkContext(location, projectionQuery.data!, ledgerQuery.data!));
  });

  const open = (location: LocationRef) => {
    setNote(null);
    setSearchParams({ location: locationKey(location) });
  };
  const done = (message: string) => {
    setNote(message);
    setSearchParams({ location: undefined });
  };

  return (
    <section>
      <h2>Audit locations</h2>
      <p class="hint">
        Check a location's real contents against what's recorded there, and correct the record.{" "}
        <A href="/placement">Back to Place cards</A>
      </p>
      <Show when={loadError()}>
        <p role="alert">{mapError(loadError()).message}</p>
      </Show>
      <Show when={note()}>
        <p class="success" role="status">
          {note()}
        </p>
      </Show>
      <Show
        when={ready()}
        fallback={
          <Show when={!loadError()}>
            <p>Loading...</p>
          </Show>
        }
      >
        <Show
          when={openLocation() === null}
          fallback={
            <Show
              when={context()}
              keyed
              fallback={<p role="alert">This location no longer exists.</p>}
            >
              {(walk) => <AuditWalk context={walk} onDone={done} />}
            </Show>
          }
        >
          <LocationList
            locations={auditableLocations(projectionQuery.data!, ledgerQuery.data!)}
            audits={auditsQuery.data!}
            onOpen={open}
          />
        </Show>
      </Show>
    </section>
  );
}
