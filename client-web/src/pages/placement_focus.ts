import type {
  PlacementCard,
  PlacementGuidance,
  PlacementLocation,
  PlacementPlace,
} from "../data/placement/request";
import {
  type PlacementSession,
  isTicked,
  mergeLocationCards,
  tickedPlaces,
} from "./placement_session";

// Accordion state for the placement page: which location is open, and the collapsed
// summaries of the rest. Only the open location pays the per-card merge, so the page
// renders one location's rows instead of the whole projection.

export type LocationSummary = PlacementPlace & {
  to_place_quantity: number;
};

export type FocusedLocation = PlacementPlace & {
  cards: PlacementCard[];
};

// Locations with work left, in cascade order, then any location kept alive only by
// this session's ticks — either not yet reflected in a stale `guidance` (the tick
// landed locally but the ledger hasn't refetched) or emptied by a refetch that
// already landed (the location dropped out of `guidance.locations` entirely).
function listedPlaces(
  guidance: PlacementGuidance | undefined,
  session: PlacementSession,
): PlacementPlace[] {
  const places: PlacementPlace[] = [];
  const seen = new Set<string>();
  for (const place of [...(guidance?.locations ?? []), ...tickedPlaces(session)]) {
    if (!seen.has(place.location_key)) {
      places.push(place);
      seen.add(place.location_key);
    }
  }
  return places;
}

function locationsByKey(guidance: PlacementGuidance | undefined): Map<string, PlacementLocation> {
  const byKey = new Map<string, PlacementLocation>();
  for (const location of guidance?.locations ?? []) {
    byKey.set(location.location_key, location);
  }
  return byKey;
}

// A card ticked this session is still counted in `guidance` until the ledger
// refetch lands (guidance is server-truth-based), so it's subtracted here the same
// way `mergeLocationCards` marks it struck in the open list.
function toPlaceQuantity(
  locations: Map<string, PlacementLocation>,
  session: PlacementSession,
  location_key: string,
): number {
  const location = locations.get(location_key);
  if (location === undefined) {
    return 0;
  }
  return location.cards.reduce(
    (sum, card) => sum + (isTicked(session, location_key, card) ? 0 : card.to_place_quantity),
    0,
  );
}

export function locationSummaries(
  guidance: PlacementGuidance | undefined,
  session: PlacementSession,
): LocationSummary[] {
  const locations = locationsByKey(guidance);
  return listedPlaces(guidance, session).map((place) => ({
    location: place.location,
    location_key: place.location_key,
    location_name: place.location_name,
    to_place_quantity: toPlaceQuantity(locations, session, place.location_key),
  }));
}

export function countLabel(to_place_quantity: number): string {
  return to_place_quantity > 0 ? `${to_place_quantity} card(s)` : "Placed";
}

// The header total: the sum of what the location lists actually show, the
// same definition `PlacementGuidance.total_unplaced` uses (#107) — but
// session-adjusted, since a tick's ledger refetch is deliberately skipped
// (#105, ADR 0015) and `guidance.total_unplaced` alone would overcount by
// what this session already struck.
export function totalToPlace(summaries: LocationSummary[]): number {
  return summaries.reduce((sum, summary) => sum + summary.to_place_quantity, 0);
}

// The router hands ?location= (a locationKey) back as string | string[] |
// undefined depending on how many query params of that name are present.
export function focusKeyFrom(param: string | string[] | undefined): string | null {
  const value = Array.isArray(param) ? param[0] : param;
  return value === undefined || value === "" ? null : value;
}

// The open location's rows with this session's struck cards merged back in, or
// null when nothing is focused or the key no longer names a listed location (rule
// renamed, all placed and the session holds no ticks for it either).
export function focusedLocation(
  guidance: PlacementGuidance | undefined,
  session: PlacementSession,
  key: string | null,
): FocusedLocation | null {
  const place = listedPlaces(guidance, session).find((listed) => listed.location_key === key);
  if (place === undefined) {
    return null;
  }
  const fresh = guidance?.locations.find((location) => location.location_key === key);
  const cards = mergeLocationCards(session, place.location_key, fresh?.cards ?? []);
  if (cards.length === 0) {
    return null;
  }
  return {
    location: place.location,
    location_key: place.location_key,
    location_name: place.location_name,
    cards,
  };
}

// Rows still to tick in the open location — drives the "Mark all N placed"
// label and whether that button is enabled.
export function unplacedRowCount(session: PlacementSession, location: FocusedLocation): number {
  return location.cards.filter((card) => !isTicked(session, location.location_key, card)).length;
}
