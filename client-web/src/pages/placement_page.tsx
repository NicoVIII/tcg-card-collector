import { For, Show, createMemo, createSignal } from "solid-js";
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
  type PlacementSession,
  type SessionCard,
  betweenLabel,
  emptySession,
  mergeLocationCards,
  tick,
  tickedLocationNames,
  untick,
} from "./placement_session";

type DisplayLocation = {
  location_name: string;
  cards: SessionCard[];
};

function placementOf(location_name: string, card: SessionCard["card"]): CardPlacementInput {
  return {
    set_code: card.set_code,
    collector_number: card.collector_number,
    location_name,
    quantity: card.to_place_quantity,
  };
}

export function PlacementPage() {
  const [session, setSession] = createSignal<PlacementSession>(emptySession());
  const [mutationError, setMutationError] = createSignal<string | null>(null);

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

  // Cascade order from guidance, plus any location that only still shows because
  // its cards were just ticked (guidance already dropped the emptied location).
  const displayLocations = (): DisplayLocation[] => {
    const current = session();
    const guidanceLocations = guidance()?.locations ?? [];
    const names: string[] = [];
    const seen = new Set<string>();
    for (const location of guidanceLocations) {
      names.push(location.location_name);
      seen.add(location.location_name);
    }
    for (const name of tickedLocationNames(current)) {
      if (!seen.has(name)) {
        names.push(name);
      }
    }
    return names
      .map((name) => {
        const fresh = guidanceLocations.find((location) => location.location_name === name);
        return {
          location_name: name,
          cards: mergeLocationCards(current, name, fresh?.cards ?? []),
        };
      })
      .filter((location) => location.cards.length > 0);
  };

  const reportError = (error: unknown) => setMutationError(mapError(error).message);

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

  const markAll = (location: DisplayLocation) => {
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
        Cards you've added but not yet sorted into their storage locations. Tick each one as you
        file it; untick a struck-through card to undo.
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
        when={displayLocations().length > 0}
        fallback={
          <Show when={!isLoading() && !isError()}>
            <p>Everything is placed. Nothing to sort right now.</p>
          </Show>
        }
      >
        <For each={displayLocations()}>
          {(location) => (
            <div class="placement-location">
              <div class="placement-location-header">
                <h3>{location.location_name}</h3>
                <button
                  type="button"
                  onClick={() => markAll(location)}
                  disabled={markMutation.isPending}
                >
                  Mark all placed
                </button>
              </div>
              <ul class="placement-list">
                <For each={location.cards}>
                  {(entry, index) => (
                    <li class="placement-row" classList={{ "placement-row-done": entry.struck }}>
                      <input
                        type="checkbox"
                        checked={entry.struck}
                        aria-label={`Placed ${entry.card.name} (${entry.card.set_code} ${entry.card.collector_number})`}
                        onChange={() =>
                          entry.struck
                            ? untickCard(location.location_name, entry)
                            : tickCard(location.location_name, entry, index())
                        }
                      />
                      <span class="placement-card">
                        <span class="placement-card-name">
                          {entry.card.to_place_quantity}x {entry.card.name}
                        </span>
                        <span class="placement-card-key">
                          {entry.card.set_code} {entry.card.collector_number}
                        </span>
                        <span class="placement-card-hint">{betweenLabel(entry.card)}</span>
                      </span>
                    </li>
                  )}
                </For>
              </ul>
            </div>
          )}
        </For>
      </Show>
    </section>
  );
}
