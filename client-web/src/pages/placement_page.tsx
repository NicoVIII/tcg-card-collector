import { For, Show, createMemo, createSignal } from "solid-js";
import { useSearchParams } from "@solidjs/router";
import { mapError } from "../data/http/error";
import { useInventoryProjectionQuery } from "../data/inventory_planning/query";
import {
  useMarkCardsPlacedMutation,
  useUnmarkCardsPlacedMutation,
} from "../data/placement/mutation";
import { buildGuidance } from "../data/placement/guidance";
import { usePlacedLedgerQuery } from "../data/placement/query";
import type { CardPlacementInput } from "../data/placement/request";
import {
  type FocusedLocation,
  type LocationSummary,
  countLabel,
  focusNameFrom,
  focusedLocation,
  locationSummaries,
} from "./placement_focus";
import {
  type PlacementSession,
  type SessionCard,
  betweenLabel,
  emptySession,
  tick,
  untick,
} from "./placement_session";

function placementOf(location_name: string, card: SessionCard["card"]): CardPlacementInput {
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
  entry: SessionCard;
  index: number;
  onTick: (location_name: string, entry: SessionCard, index: number) => void;
  onUntick: (location_name: string, entry: SessionCard) => void;
};

function PlacementRow(props: PlacementRowProps) {
  return (
    <li class="placement-row" classList={{ "placement-row-done": props.entry.struck }}>
      <input
        type="checkbox"
        checked={props.entry.struck}
        aria-label={`Placed ${props.entry.card.name} (${props.entry.card.set_code} ${props.entry.card.collector_number})`}
        onChange={() =>
          props.entry.struck
            ? props.onUntick(props.location_name, props.entry)
            : props.onTick(props.location_name, props.entry, props.index)
        }
      />
      <span class="placement-card">
        <span class="placement-card-name">
          {props.entry.card.to_place_quantity}x {props.entry.card.name}
        </span>
        <span class="placement-card-key">
          {props.entry.card.set_code} {props.entry.card.collector_number} ({props.entry.card.finish}
          ·{props.entry.card.language})
        </span>
        <span class="placement-card-hint">{betweenLabel(props.entry.card)}</span>
      </span>
    </li>
  );
}

type LocationPanelProps = {
  location: FocusedLocation;
  markAllPending: boolean;
  onTick: (location_name: string, entry: SessionCard, index: number) => void;
  onUntick: (location_name: string, entry: SessionCard) => void;
  onMarkAll: (location: FocusedLocation) => void;
};

function LocationPanel(props: LocationPanelProps) {
  return (
    <div class="placement-panel">
      <button
        type="button"
        onClick={() => props.onMarkAll(props.location)}
        disabled={props.markAllPending}
      >
        Mark all placed
      </button>
      <ul class="placement-list">
        <For each={props.location.cards}>
          {(entry, index) => (
            <PlacementRow
              location_name={props.location.location_name}
              entry={entry}
              index={index()}
              onTick={props.onTick}
              onUntick={props.onUntick}
            />
          )}
        </For>
      </ul>
    </div>
  );
}

type LocationRowProps = {
  summary: LocationSummary;
  panelId: string;
  isOpen: boolean;
  focused: FocusedLocation | null;
  markAllPending: boolean;
  onToggle: (location_name: string, headerEl: HTMLElement) => void;
  onTick: (location_name: string, entry: SessionCard, index: number) => void;
  onUntick: (location_name: string, entry: SessionCard) => void;
  onMarkAll: (location: FocusedLocation) => void;
};

function LocationRow(props: LocationRowProps) {
  let headerRef: HTMLButtonElement | undefined;

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
          onClick={() => headerRef && props.onToggle(props.summary.location_name, headerRef)}
        >
          <span aria-hidden="true">{props.isOpen ? "▾" : "▸"}</span>
          <span>{props.summary.location_name}</span>
          <span>{countLabel(props.summary)}</span>
        </button>
      </h3>
      <Show when={props.isOpen && props.focused !== null}>
        <div id={props.panelId}>
          <LocationPanel
            location={props.focused as FocusedLocation}
            markAllPending={props.markAllPending}
            onTick={props.onTick}
            onUntick={props.onUntick}
            onMarkAll={props.onMarkAll}
          />
        </div>
      </Show>
    </div>
  );
}

export function PlacementPage() {
  const [session, setSession] = createSignal<PlacementSession>(emptySession());
  const [mutationError, setMutationError] = createSignal<string | null>(null);
  const [searchParams, setSearchParams] = useSearchParams<{ location?: string }>();

  const projectionQuery = useInventoryProjectionQuery();
  const ledgerQuery = usePlacedLedgerQuery();
  const markMutation = useMarkCardsPlacedMutation();
  const unmarkMutation = useUnmarkCardsPlacedMutation();

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

  const isLoading = () => projectionQuery.isLoading || ledgerQuery.isLoading;
  const isError = () => projectionQuery.isError || ledgerQuery.isError;
  const loadError = () => projectionQuery.error ?? ledgerQuery.error;

  const focusName = () => focusNameFrom(searchParams.location);

  // Collapsed summaries for every location; only the open one pays the per-card
  // merge, so ticking a card no longer re-derives (or re-renders) the rest.
  const summaries = createMemo<LocationSummary[]>(() => locationSummaries(guidance(), session()));
  const focused = createMemo<FocusedLocation | null>(() =>
    focusedLocation(guidance(), session(), focusName()),
  );

  const reportError = (error: unknown) => setMutationError(mapError(error).message);

  // A history entry per open/close, not a replace: on a phone, back-to-close is
  // the affordance alongside re-tapping the header. Scroll the tapped header back
  // into view in case closing a location above it moved the page under it.
  const toggleFocus = (location_name: string, headerEl: HTMLElement) => {
    setSearchParams({ location: focusName() === location_name ? undefined : location_name });
    headerEl.scrollIntoView({ block: "nearest" });
  };

  const tickCard = (location_name: string, entry: SessionCard, index: number) => {
    setMutationError(null);
    setSession(tick(session(), location_name, entry.card, index));
    markMutation.mutate([placementOf(location_name, entry.card)], { onError: reportError });
  };

  const untickCard = (location_name: string, entry: SessionCard) => {
    setMutationError(null);
    setSession(untick(session(), location_name, entry.card));
    unmarkMutation.mutate([placementOf(location_name, entry.card)], { onError: reportError });
  };

  const markAll = (location: FocusedLocation) => {
    setMutationError(null);
    let next = session();
    const placements: CardPlacementInput[] = [];
    location.cards.forEach((entry, index) => {
      if (!entry.struck) {
        next = tick(next, location.location_name, entry.card, index);
        placements.push(placementOf(location.location_name, entry.card));
      }
    });
    if (placements.length === 0) {
      return;
    }
    setSession(next);
    markMutation.mutate(placements, { onError: reportError });
  };

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
      <Show when={mutationError() !== null}>
        <p role="alert">{mutationError()}</p>
      </Show>
      <Show when={(guidance()?.total_unplaced ?? 0) > 0}>
        <p class="hint">{guidance()?.total_unplaced} card(s) still to place.</p>
      </Show>
      <Show
        when={summaries().length > 0}
        fallback={
          <Show when={!isLoading() && !isError()}>
            <p>Everything is placed. Nothing to sort right now.</p>
          </Show>
        }
      >
        <For each={summaries()}>
          {(summary, index) => (
            <LocationRow
              summary={summary}
              panelId={`placement-panel-${index()}`}
              isOpen={focusName() === summary.location_name}
              focused={focused()}
              markAllPending={markMutation.isPending}
              onToggle={toggleFocus}
              onTick={tickCard}
              onUntick={untickCard}
              onMarkAll={markAll}
            />
          )}
        </For>
      </Show>
    </section>
  );
}
