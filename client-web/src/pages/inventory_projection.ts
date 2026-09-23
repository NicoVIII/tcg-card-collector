import type { CardFilter } from "../lib/card_filter";
import type { InventoryProjection, ProjectionCard } from "../data/inventory_planning/request";

// Collapse/page/filter derivations for the Inventory page's projection
// section (#55). Pure so they're node-testable — the page (inventory_page.tsx)
// owns only JSX and signal wiring, per client-web/AGENTS.md.

export const PROJECTION_PAGE_SIZE = 100;

export type ProjectionLocationSummary = {
  location_name: string;
  is_bulk: boolean;
  total_quantity: number;
  match_quantity: number;
};

// Same semantics as the #54 server-side filter (name: case-insensitive
// substring; set: case-insensitive exact) so a filtered projection agrees
// with what Collection/Catalog search would call a match.
export function cardMatches(card: ProjectionCard, filter: CardFilter): boolean {
  const name = filter.name.trim().toLowerCase();
  const setCode = filter.set_code.trim().toLowerCase();
  if (name !== "" && !card.name.toLowerCase().includes(name)) {
    return false;
  }
  if (setCode !== "" && card.set_code.toLowerCase() !== setCode) {
    return false;
  }
  return true;
}

function matchCount(cards: ProjectionCard[], filter: CardFilter): number {
  return cards.reduce((sum, card) => sum + (cardMatches(card, filter) ? card.quantity : 0), 0);
}

export function filterIsActive(filter: CardFilter): boolean {
  return filter.name.trim() !== "" || filter.set_code.trim() !== "";
}

// Every location when the filter is empty; with an active filter, only
// locations holding a match — "where is card X" should list only the
// locations that hold it, not every location at a zero count.
export function projectionSummaries(
  projection: InventoryProjection | undefined,
  filter: CardFilter,
): ProjectionLocationSummary[] {
  const active = filterIsActive(filter);
  const summaries = (projection?.locations ?? []).map((location) => ({
    location_name: location.location_name,
    is_bulk: location.rule_id === "",
    total_quantity: location.total_quantity,
    match_quantity: matchCount(location.cards, filter),
  }));
  return summaries.filter((summary) => !active || summary.match_quantity > 0);
}

// The open location's filtered rows, or null when nothing is open, the name
// no longer names a location (rule renamed), or the filter leaves it empty.
export function openLocationCards(
  projection: InventoryProjection | undefined,
  name: string | null,
  filter: CardFilter,
): ProjectionCard[] | null {
  if (name === null) {
    return null;
  }
  const location = projection?.locations.find((candidate) => candidate.location_name === name);
  if (location === undefined) {
    return null;
  }
  const cards = location.cards.filter((card) => cardMatches(card, filter));
  return cards.length === 0 ? null : cards;
}

export function countLabel(summary: ProjectionLocationSummary, filterActive: boolean): string {
  return filterActive
    ? `${summary.match_quantity} of ${summary.total_quantity} card(s)`
    : `${summary.total_quantity} card(s)`;
}
