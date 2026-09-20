import type {
  PlacementCard,
  PlacementGuidance,
  PlacementLocation,
} from "../data/placement/request";
import {
  type PlacementSession,
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
  cards: PlacementCard[];
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

function locationsByName(guidance: PlacementGuidance | undefined): Map<string, PlacementLocation> {
  const byName = new Map<string, PlacementLocation>();
  for (const location of guidance?.locations ?? []) {
    byName.set(location.location_name, location);
  }
  return byName;
}

// A card ticked this session is still counted in `guidance` until the ledger
// refetch lands (guidance is server-truth-based), so it's subtracted here the same
// way `mergeLocationCards` marks it struck in the open list.
function toPlaceQuantity(
  locations: Map<string, PlacementLocation>,
  session: PlacementSession,
  location_name: string,
): number {
  const location = locations.get(location_name);
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
  const locations = locationsByName(guidance);
  return listedNames(guidance, session).map((location_name) => ({
    location_name,
    to_place_quantity: toPlaceQuantity(locations, session, location_name),
  }));
}

export function countLabel(summary: LocationSummary): string {
  return summary.to_place_quantity > 0 ? `${summary.to_place_quantity} card(s)` : "Placed";
}

// The header total: the sum of what the location lists actually show, the
// same definition `PlacementGuidance.total_unplaced` uses (#107) — but
// session-adjusted, since a tick's ledger refetch is deliberately skipped
// (#105, ADR 0015) and `guidance.total_unplaced` alone would overcount by
// what this session already struck.
export function totalToPlace(summaries: LocationSummary[]): number {
  return summaries.reduce((sum, summary) => sum + summary.to_place_quantity, 0);
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

// Rows still to tick in the open location — drives the "Mark all N placed"
// label and whether that button is enabled.
export function unplacedRowCount(session: PlacementSession, location: FocusedLocation): number {
  return location.cards.filter((card) => !isTicked(session, location.location_name, card)).length;
}
