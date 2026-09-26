import { For, Show, createMemo, createSignal } from "solid-js";
import { useSearchParams } from "@solidjs/router";
import { mapError } from "../data/http/error";
import { createMutationError } from "../lib/mutation_error";
import { useInventoryProjectionQuery } from "../data/inventory_planning/query";
import {
  useMarkCardsPlacedMutation,
  useRelocatePlacedCardsMutation,
  useUnmarkCardsPlacedMutation,
} from "../data/placement/mutation";
import { buildGuidance } from "../data/placement/guidance";
import { type ResortEntry, type ResortGroup, buildResortWorklist } from "../data/placement/resort";
import { usePlacedLedgerQuery } from "../data/placement/query";
import type { CardPlacementInput, PlacementCard } from "../data/placement/request";
import {
  type FocusedLocation,
  type LocationSummary,
  countLabel,
  focusNameFrom,
  focusedLocation,
  locationSummaries,
  totalToPlace,
  unplacedRowCount,
} from "./placement_focus";
import {
  type MarkAllBatch,
  type PlacementSession,
  betweenLabel,
  emptySession,
  isSectionHeader,
  isTicked,
  restoreTicks,
  sectionLabel,
  tick,
  tickAll,
  untick,
  untickAll,
  withSectionHeaders,
} from "./placement_session";
import {
  type ResortSession,
  emptyResortSession,
  filterResortWorklist,
  resolveEntry,
  resolveGroup,
  unresolveEntry,
  unresolveGroup,
} from "./resort_session";

type LastResortAction =
  | { kind: "pull_out"; from_location: string; entry: ResortEntry }
  | { kind: "relocate"; from_location: string; to_location: string };

function lastResortActionLabel(action: LastResortAction): string {
  return action.kind === "pull_out" ? "Pulled out." : "Record updated.";
}

function entryPlacement(from_location: string, entry: ResortEntry): CardPlacementInput {
  return {
    set_code: entry.set_code,
    collector_number: entry.collector_number,
    finish: entry.finish,
    language: entry.language,
    location_name: from_location,
    quantity: entry.quantity,
  };
}

type ResortEntryRowProps = {
  from_location: string;
  entry: ResortEntry;
  pending: boolean;
  onPullOut: (from_location: string, entry: ResortEntry) => void;
};

function ResortEntryRow(props: ResortEntryRowProps) {
  return (
    <li class="placement-row">
      <span class="placement-card">
        <span class="placement-card-name">
          {props.entry.quantity}x{" "}
          {props.entry.name === ""
            ? `${props.entry.set_code} ${props.entry.collector_number}`
            : props.entry.name}
        </span>
        <span class="placement-card-key">
          {props.entry.set_code} {props.entry.collector_number} ({props.entry.finish}·
          {props.entry.language})
        </span>
        <span class="placement-card-hint">
          {props.entry.destinations.length === 0
            ? "No location currently wants this copy."
            : `Belongs at ${props.entry.destinations.map((d) => d.location_name).join(", ")}.`}
        </span>
      </span>
      <button
        type="button"
        class="resort-pull-out"
        disabled={props.pending}
        onClick={() => props.onPullOut(props.from_location, props.entry)}
      >
        Pull out
      </button>
    </li>
  );
}

type ResortGroupPanelProps = {
  group: ResortGroup;
  pending: boolean;
  onPullOut: (from_location: string, entry: ResortEntry) => void;
  onUpdateRecordOnly: (group: ResortGroup) => void;
};

function ResortGroupPanel(props: ResortGroupPanelProps) {
  return (
    <div class="placement-panel">
      <h4>{props.group.from_location}</h4>
      <Show when={props.group.looks_like_rename}>
        {(destination) => (
          <p class="hint">
            Looks like a rename — nothing physically moved.{" "}
            <button
              type="button"
              disabled={props.pending}
              onClick={() => props.onUpdateRecordOnly(props.group)}
            >
              Update record only: {props.group.from_location} → {destination()}
            </button>
          </p>
        )}
      </Show>
      <ul class="placement-list">
        <For each={props.group.entries}>
          {(entry) => (
            <ResortEntryRow
              from_location={props.group.from_location}
              entry={entry}
              pending={props.pending}
              onPullOut={props.onPullOut}
            />
          )}
        </For>
      </ul>
    </div>
  );
}

function placementOf(location_name: string, card: PlacementCard): CardPlacementInput {
  return {
    set_code: card.set_code,
    collector_number: card.collector_number,
    finish: card.finish,
    language: card.language,
    location_name,
    quantity: card.to_place_quantity,
  };
}

type PlacementRowProps = {
  location_name: string;
  card: PlacementCard;
  session: PlacementSession;
  index: number;
  onTick: (location_name: string, card: PlacementCard, index: number) => void;
  onUntick: (location_name: string, card: PlacementCard) => void;
};

// struck is asked of the session per render rather than carried on the row
// object — that's what keeps `props.card` the same reference across a tick
// elsewhere in the list, which is what lets <For> (keyed by reference in
// LocationPanel below) skip rebuilding every other row (#105).
function PlacementRow(props: PlacementRowProps) {
  const struck = () => isTicked(props.session, props.location_name, props.card);

  return (
    <li class="placement-row" classList={{ "placement-row-done": struck() }}>
      <input
        type="checkbox"
        checked={struck()}
        aria-label={`Placed ${props.card.name} (${props.card.set_code} ${props.card.collector_number})`}
        onChange={() =>
          struck()
            ? props.onUntick(props.location_name, props.card)
            : props.onTick(props.location_name, props.card, props.index)
        }
      />
      <span class="placement-card">
        <span class="placement-card-name">
          {props.card.to_place_quantity}x {props.card.name}
        </span>
        <span class="placement-card-key">
          {props.card.set_code} {props.card.collector_number} ({props.card.finish}·
          {props.card.language})
        </span>
        <span class="placement-card-hint">
          {betweenLabel(props.session, props.location_name, props.card)}
        </span>
      </span>
    </li>
  );
}

type LocationPanelProps = {
  location: FocusedLocation;
  session: PlacementSession;
  markAllPending: boolean;
  undoable: MarkAllBatch | null;
  undoPending: boolean;
  onTick: (location_name: string, card: PlacementCard, index: number) => void;
  onUntick: (location_name: string, card: PlacementCard) => void;
  onMarkAll: (location: FocusedLocation) => void;
  onUndoMarkAll: (batch: MarkAllBatch) => void;
};

function LocationPanel(props: LocationPanelProps) {
  const undoableHere = () =>
    props.undoable !== null && props.undoable.location_name === props.location.location_name
      ? props.undoable
      : null;
  const unplaced = () => unplacedRowCount(props.session, props.location);
  const items = createMemo(() => withSectionHeaders(props.location.cards));
  // A card's tick position must stay its index among cards alone — section
  // headers interleaved by withSectionHeaders don't shift it — so
  // mergeLocationCards's recorded re-insertion spot stays correct. Memoized
  // once per location.cards change rather than looked up per row.
  const cardIndex = createMemo(() => {
    const map = new Map<PlacementCard, number>();
    props.location.cards.forEach((card, index) => map.set(card, index));
    return map;
  });

  return (
    <div class="placement-panel">
      <button
        type="button"
        onClick={() => props.onMarkAll(props.location)}
        disabled={props.markAllPending || unplaced() === 0}
      >
        Mark all {unplaced()} placed
      </button>
      <Show when={undoableHere()}>
        {(batch) => (
          <p class="hint" role="status">
            {batch().cards.length} card(s) marked placed.{" "}
            <button
              type="button"
              disabled={props.undoPending}
              onClick={() => props.onUndoMarkAll(batch())}
            >
              Undo
            </button>
          </p>
        )}
      </Show>
      <ul class="placement-list">
        <For each={items()}>
          {(item) =>
            isSectionHeader(item) ? (
              <li class="placement-section">
                <h3>{sectionLabel(item)}</h3>
              </li>
            ) : (
              <PlacementRow
                location_name={props.location.location_name}
                card={item}
                session={props.session}
                index={cardIndex().get(item) ?? 0}
                onTick={props.onTick}
                onUntick={props.onUntick}
              />
            )
          }
        </For>
      </ul>
    </div>
  );
}

function summaryFor(summaries: LocationSummary[], location_name: string): LocationSummary {
  return (
    summaries.find((summary) => summary.location_name === location_name) ?? {
      location_name,
      to_place_quantity: 0,
    }
  );
}

type LocationRowProps = {
  location_name: string;
  // The whole-page summaries list, not this row's own summary — <For> below
  // keys the outer list by `location_name` (a stable primitive) precisely so
  // a tick's fresh `summaries()` array doesn't tear down every LocationRow,
  // including the open one and its whole card list (#105). Passing a fresh
  // LocationSummary object per row instead would undo that: it changes
  // reference every tick just like the row objects mergeLocationCards used
  // to build, and <For> would be back to keying on ephemeral identity.
  summaries: () => LocationSummary[];
  panelId: string;
  isOpen: boolean;
  focused: FocusedLocation | null;
  session: PlacementSession;
  markAllPending: boolean;
  undoable: MarkAllBatch | null;
  undoPending: boolean;
  onToggle: (location_name: string, headerEl: HTMLElement) => void;
  onTick: (location_name: string, card: PlacementCard, index: number) => void;
  onUntick: (location_name: string, card: PlacementCard) => void;
  onMarkAll: (location: FocusedLocation) => void;
  onUndoMarkAll: (batch: MarkAllBatch) => void;
};

function LocationRow(props: LocationRowProps) {
  let headerRef: HTMLButtonElement | undefined;
  const summary = () => summaryFor(props.summaries(), props.location_name);

  return (
    <div class="placement-location">
      <h3 class="placement-location-header">
        <button
          ref={(element) => {
            headerRef = element;
          }}
          type="button"
          class="placement-location-toggle"
          aria-expanded={props.isOpen}
          aria-controls={props.panelId}
          onClick={() => headerRef && props.onToggle(props.location_name, headerRef)}
        >
          <span aria-hidden="true">{props.isOpen ? "▾" : "▸"}</span>
          <span>{props.location_name}</span>
          <span>{countLabel(summary())}</span>
        </button>
      </h3>
      <Show when={props.isOpen && props.focused !== null}>
        <div id={props.panelId}>
          <LocationPanel
            location={props.focused as FocusedLocation}
            session={props.session}
            markAllPending={props.markAllPending}
            undoable={props.undoable}
            undoPending={props.undoPending}
            onTick={props.onTick}
            onUntick={props.onUntick}
            onMarkAll={props.onMarkAll}
            onUndoMarkAll={props.onUndoMarkAll}
          />
        </div>
      </Show>
    </div>
  );
}

type ResortActionsDeps = {
  resortSession: () => ResortSession;
  setResortSession: (session: ResortSession) => void;
  setLastMarkAll: (batch: MarkAllBatch | null) => void;
  setLastResortAction: (action: LastResortAction | null) => void;
  clearMutationError: () => void;
  reportMutationError: (error: unknown) => void;
  markMutation: { mutate: ReturnType<typeof useMarkCardsPlacedMutation>["mutate"] };
  unmarkMutation: { mutate: ReturnType<typeof useUnmarkCardsPlacedMutation>["mutate"] };
  relocateMutation: { mutate: ReturnType<typeof useRelocatePlacedCardsMutation>["mutate"] };
};

// Out of PlacementPage's own body so its branching doesn't count against that
// component's complexity budget — each action here is small and single-
// purpose on its own; wiring them into signals is what made the host function
// too big.
function createResortActions(deps: ResortActionsDeps) {
  const pullOutEntry = (from_location: string, entry: ResortEntry) => {
    deps.clearMutationError();
    deps.setLastMarkAll(null);
    deps.setLastResortAction(null);
    deps.setResortSession(resolveEntry(deps.resortSession(), from_location, entry));
    deps.unmarkMutation.mutate([entryPlacement(from_location, entry)], {
      onSuccess: () => deps.setLastResortAction({ kind: "pull_out", from_location, entry }),
      onError: (error) => {
        deps.setResortSession(unresolveEntry(deps.resortSession(), from_location, entry));
        deps.reportMutationError(error);
      },
    });
  };

  const updateRecordOnly = (group: ResortGroup) => {
    const to_location = group.looks_like_rename;
    if (to_location === null) {
      return;
    }
    deps.clearMutationError();
    deps.setLastMarkAll(null);
    deps.setLastResortAction(null);
    deps.setResortSession(resolveGroup(deps.resortSession(), group.from_location));
    deps.relocateMutation.mutate(
      { from_location: group.from_location, to_location },
      {
        onSuccess: () =>
          deps.setLastResortAction({
            kind: "relocate",
            from_location: group.from_location,
            to_location,
          }),
        onError: (error) => {
          deps.setResortSession(unresolveGroup(deps.resortSession(), group.from_location));
          deps.reportMutationError(error);
        },
      },
    );
  };

  // Reverses whichever of the two resort actions ran last: re-marking a
  // pulled-out copy restores the drift it pulled out of, and relocating the
  // other direction puts a "just fixed the record" group back the way it was.
  const undoPullOut = (action: Extract<LastResortAction, { kind: "pull_out" }>) => {
    deps.markMutation.mutate([entryPlacement(action.from_location, action.entry)], {
      onSuccess: () =>
        deps.setResortSession(
          unresolveEntry(deps.resortSession(), action.from_location, action.entry),
        ),
      onError: (error) => deps.reportMutationError(error),
    });
  };

  const undoRelocate = (action: Extract<LastResortAction, { kind: "relocate" }>) => {
    deps.relocateMutation.mutate(
      { from_location: action.to_location, to_location: action.from_location },
      {
        onSuccess: () =>
          deps.setResortSession(unresolveGroup(deps.resortSession(), action.from_location)),
        onError: (error) => deps.reportMutationError(error),
      },
    );
  };

  const undoResortAction = (action: LastResortAction) => {
    deps.clearMutationError();
    deps.setLastResortAction(null);
    return action.kind === "pull_out" ? undoPullOut(action) : undoRelocate(action);
  };

  return { pullOutEntry, updateRecordOnly, undoResortAction };
}

export function PlacementPage() {
  const [session, setSession] = createSignal<PlacementSession>(emptySession());
  // The last mark-all batch, offered as a single undo — cleared by any other
  // placement action so the offer always refers to "the thing you just did".
  const [lastMarkAll, setLastMarkAll] = createSignal<MarkAllBatch | null>(null);
  const [resortSession, setResortSession] = createSignal<ResortSession>(emptyResortSession());
  const [lastResortAction, setLastResortAction] = createSignal<LastResortAction | null>(null);
  const mutationError = createMutationError();
  const [searchParams, setSearchParams] = useSearchParams<{ location?: string }>();

  const projectionQuery = useInventoryProjectionQuery();
  const ledgerQuery = usePlacedLedgerQuery();
  const markMutation = useMarkCardsPlacedMutation();
  const unmarkMutation = useUnmarkCardsPlacedMutation();
  const relocateMutation = useRelocatePlacedCardsMutation();

  // Guidance is derived client-side: the projection (cached, invariant to
  // placement) folded against the placed ledger (cheap, refetched per tick).
  const guidance = createMemo(() => {
    const projection = projectionQuery.data;
    const ledger = ledgerQuery.data;
    if (projection === undefined || ledger === undefined) {
      return undefined;
    }
    return buildGuidance(projection, ledger);
  });

  // Same two inputs, folded the other way: copies the ledger records
  // somewhere the projection no longer sends them (#107). Resolved
  // entries/groups are hidden immediately, before the ledger refetch confirms
  // it — the same optimistic-before-refetch posture as a placement tick.
  const resortWorklist = createMemo(() => {
    const projection = projectionQuery.data;
    const ledger = ledgerQuery.data;
    if (projection === undefined || ledger === undefined) {
      return undefined;
    }
    return filterResortWorklist(buildResortWorklist(projection, ledger), resortSession());
  });
  const resortGroups = createMemo(() => resortWorklist()?.groups ?? []);
  const misplacedCount = createMemo(() => resortWorklist()?.total_misplaced ?? 0);
  const resortActionPending = createMemo(
    () => unmarkMutation.isPending || relocateMutation.isPending,
  );
  const undoResortPending = createMemo(
    () => unmarkMutation.isPending || markMutation.isPending || relocateMutation.isPending,
  );

  const isLoading = () => projectionQuery.isLoading || ledgerQuery.isLoading;
  const isError = () => projectionQuery.isError || ledgerQuery.isError;
  const loadError = () => projectionQuery.error ?? ledgerQuery.error;
  const nothingToDo = createMemo(() => !isLoading() && !isError() && misplacedCount() === 0);

  const focusName = () => focusNameFrom(searchParams.location);

  // Collapsed summaries for every location; only the open one pays the per-card
  // merge, so ticking a card no longer re-derives (or re-renders) the rest.
  const summaries = createMemo<LocationSummary[]>(() => locationSummaries(guidance(), session()));
  // Rendered separately from `summaries()`: a fresh LocationSummary object per
  // location every tick would defeat the point below (<For> keys by
  // reference), but a location's *name* is a stable string across a tick, so
  // deriving just the names keeps the open location's row keyed the same way
  // tick over tick.
  const locationNames = createMemo<string[]>(() =>
    summaries().map((summary) => summary.location_name),
  );
  const focused = createMemo<FocusedLocation | null>(() =>
    focusedLocation(guidance(), session(), focusName()),
  );

  // A history entry per open/close, not a replace: on a phone, back-to-close is
  // the affordance alongside re-tapping the header. Scroll the tapped header back
  // into view in case closing a location above it moved the page under it.
  const toggleFocus = (location_name: string, headerEl: HTMLElement) => {
    setLastMarkAll(null);
    setLastResortAction(null);
    setSearchParams({ location: focusName() === location_name ? undefined : location_name });
    headerEl.scrollIntoView({ block: "nearest" });
  };

  // Failed mutations must not leave the optimistic tick standing — the ledger
  // never got it, so the row must go back to what it looked like before this
  // action, without disturbing any tick made while the request was in flight.
  const rollback = (before: PlacementSession, location_name: string, cards: PlacementCard[]) => {
    setSession(restoreTicks(session(), before, location_name, cards));
  };

  const tickCard = (location_name: string, card: PlacementCard, index: number) => {
    mutationError.clear();
    setLastMarkAll(null);
    setLastResortAction(null);
    const before = session();
    setSession(tick(before, location_name, card, index));
    markMutation.mutate([placementOf(location_name, card)], {
      onError: (error) => {
        rollback(before, location_name, [card]);
        mutationError.report(error);
      },
    });
  };

  const untickCard = (location_name: string, card: PlacementCard) => {
    mutationError.clear();
    setLastMarkAll(null);
    setLastResortAction(null);
    const before = session();
    setSession(untick(before, location_name, card));
    unmarkMutation.mutate([placementOf(location_name, card)], {
      onError: (error) => {
        rollback(before, location_name, [card]);
        mutationError.report(error);
      },
    });
  };

  const markAll = (location: FocusedLocation) => {
    mutationError.clear();
    setLastMarkAll(null);
    setLastResortAction(null);
    const before = session();
    const result = tickAll(before, location.location_name, location.cards);
    if (result === null) {
      return;
    }
    setSession(result.session);
    const placements: CardPlacementInput[] = result.batch.cards.map((card) =>
      placementOf(location.location_name, card),
    );
    markMutation.mutate(placements, {
      onSuccess: () => setLastMarkAll(result.batch),
      onError: (error) => {
        rollback(before, location.location_name, result.batch.cards);
        mutationError.report(error);
      },
    });
  };

  const undoMarkAll = (batch: MarkAllBatch) => {
    mutationError.clear();
    setLastMarkAll(null);
    setLastResortAction(null);
    const before = session();
    setSession(untickAll(before, batch));
    const placements: CardPlacementInput[] = batch.cards.map((card) =>
      placementOf(batch.location_name, card),
    );
    unmarkMutation.mutate(placements, {
      onError: (error) => {
        rollback(before, batch.location_name, batch.cards);
        setLastMarkAll(batch);
        mutationError.report(error);
      },
    });
  };

  const { pullOutEntry, updateRecordOnly, undoResortAction } = createResortActions({
    resortSession,
    setResortSession,
    setLastMarkAll,
    setLastResortAction,
    clearMutationError: mutationError.clear,
    reportMutationError: mutationError.report,
    markMutation,
    unmarkMutation,
    relocateMutation,
  });

  return (
    <section>
      <h2>Place cards</h2>
      <p class="hint">
        Cards you've added but not yet sorted into their storage locations. Open a location to file
        it; tick each card as you place it, untick a struck-through card to undo.
      </p>
      <Show when={isLoading()}>
        <p>Loading placement guidance...</p>
      </Show>
      <Show when={isError()}>
        <p role="alert">{mapError(loadError()).message}</p>
      </Show>
      <Show when={mutationError.messageFor() !== null}>
        <p role="alert">{mutationError.messageFor()}</p>
      </Show>
      <Show when={totalToPlace(summaries()) > 0}>
        <p class="hint">{totalToPlace(summaries())} card(s) still to place.</p>
      </Show>
      <Show when={misplacedCount() > 0}>
        <p class="hint">{misplacedCount()} card(s) need re-sorting.</p>
      </Show>
      <Show when={lastResortAction()}>
        {(action) => (
          <p class="hint" role="status">
            {lastResortActionLabel(action())}{" "}
            <button
              type="button"
              disabled={undoResortPending()}
              onClick={() => undoResortAction(action())}
            >
              Undo
            </button>
          </p>
        )}
      </Show>
      <Show when={misplacedCount() > 0}>
        <section class="placement-location">
          <h3>Re-sort ({misplacedCount()})</h3>
          <p class="hint">
            These copies are recorded in a location the current rules no longer send them to.
          </p>
          <For each={resortGroups()}>
            {(group) => (
              <ResortGroupPanel
                group={group}
                pending={resortActionPending()}
                onPullOut={pullOutEntry}
                onUpdateRecordOnly={updateRecordOnly}
              />
            )}
          </For>
        </section>
      </Show>
      <Show
        when={summaries().length > 0}
        fallback={
          <Show when={nothingToDo()}>
            <p>Everything is placed. Nothing to sort right now.</p>
          </Show>
        }
      >
        <For each={locationNames()}>
          {(location_name, index) => (
            <LocationRow
              location_name={location_name}
              summaries={summaries}
              panelId={`placement-panel-${index()}`}
              isOpen={focusName() === location_name}
              focused={focused()}
              session={session()}
              markAllPending={markMutation.isPending}
              undoable={lastMarkAll()}
              undoPending={unmarkMutation.isPending}
              onToggle={toggleFocus}
              onTick={tickCard}
              onUntick={untickCard}
              onMarkAll={markAll}
              onUndoMarkAll={undoMarkAll}
            />
          )}
        </For>
      </Show>
    </section>
  );
}
