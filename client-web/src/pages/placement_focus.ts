import type { PlacementGuidance } from "../data/placement/request";
import {
  type PlacementSession,
  type SessionCard,
  isTicked,
  mergeLocationCards,
  tickedLocationNames,
} from "./placement_session";

// Accordion state for the placement page: which location is open, and the collapsed
// summaries of the rest. Only the open location pays the per-card merge, so the page
// renders one location's rows instead of the whole projection.

export type LocationSummary = {
  location_name: string;
  to_place_quantity: number;
};

export type FocusedLocation = {
  location_name: string;
  cards: SessionCard[];
};

// Locations with work left, in cascade order, then any location kept alive only by
// this session's ticks — either not yet reflected in a stale `guidance` (the tick
// landed locally but the ledger hasn't refetched) or emptied by a refetch that
// already landed (the location dropped out of `guidance.locations` entirely).
function listedNames(guidance: PlacementGuidance | undefined, session: PlacementSession): string[] {
  const names: string[] = [];
  const seen = new Set<string>();
  for (const location of guidance?.locations ?? []) {
    names.push(location.location_name);
    seen.add(location.location_name);
  }
  for (const name of tickedLocationNames(session)) {
    if (!seen.has(name)) {
      names.push(name);
      seen.add(name);
    }
  }
  return names;
}

// A card ticked this session is still counted in `guidance` until the ledger
// refetch lands (guidance is server-truth-based), so it's subtracted here the same
// way `mergeLocationCards` marks it struck in the open list.
function toPlaceQuantity(
  guidance: PlacementGuidance | undefined,
  session: PlacementSession,
  location_name: string,
): number {
  const location = guidance?.locations.find((entry) => entry.location_name === location_name);
  if (location === undefined) {
    return 0;
  }
  return location.cards.reduce(
    (sum, card) => sum + (isTicked(session, location_name, card) ? 0 : card.to_place_quantity),
    0,
  );
}

export function locationSummaries(
  guidance: PlacementGuidance | undefined,
  session: PlacementSession,
): LocationSummary[] {
  return listedNames(guidance, session).map((location_name) => ({
    location_name,
    to_place_quantity: toPlaceQuantity(guidance, session, location_name),
  }));
}

export function countLabel(summary: LocationSummary): string {
  return summary.to_place_quantity > 0 ? `${summary.to_place_quantity} card(s)` : "Placed";
}

// The router hands ?location= back as string | string[] | undefined depending on
// how many query params of that name are present.
export function focusNameFrom(param: string | string[] | undefined): string | null {
  const value = Array.isArray(param) ? param[0] : param;
  return value === undefined || value === "" ? null : value;
}

// The open location's rows with this session's struck cards merged back in, or
// null when nothing is focused or the name no longer names a listed location (rule
// renamed, all placed and the session holds no ticks for it either).
export function focusedLocation(
  guidance: PlacementGuidance | undefined,
  session: PlacementSession,
  name: string | null,
): FocusedLocation | null {
  if (name === null || !listedNames(guidance, session).includes(name)) {
    return null;
  }
  const fresh = guidance?.locations.find((location) => location.location_name === name);
  const cards = mergeLocationCards(session, name, fresh?.cards ?? []);
  if (cards.length === 0) {
    return null;
  }
  return { location_name: name, cards };
}
