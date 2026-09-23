import type { InventoryProjection, ProjectionCard } from "../data/inventory_planning/request";

// Collapse/page derivations for the Inventory page's projection section
// (#55). Pure so they're node-testable — the page (inventory_page.tsx) owns
// only JSX and signal wiring, per client-web/AGENTS.md.

export const PROJECTION_PAGE_SIZE = 100;

export type ProjectionLocationSummary = {
  location_name: string;
  is_bulk: boolean;
  total_quantity: number;
};

export function projectionSummaries(
  projection: InventoryProjection | undefined,
): ProjectionLocationSummary[] {
  return (projection?.locations ?? []).map((location) => ({
    location_name: location.location_name,
    is_bulk: location.rule_id === "",
    total_quantity: location.total_quantity,
  }));
}

// The open location's cards, or null when nothing is open or the name no
// longer names a location (rule renamed).
export function openLocationCards(
  projection: InventoryProjection | undefined,
  name: string | null,
): ProjectionCard[] | null {
  if (name === null) {
    return null;
  }
  const location = projection?.locations.find((candidate) => candidate.location_name === name);
  return location === undefined ? null : location.cards;
}

export function countLabel(summary: ProjectionLocationSummary): string {
  return `${summary.total_quantity} card(s)`;
}
