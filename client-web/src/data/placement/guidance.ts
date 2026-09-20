import type { InventoryProjection, ProjectionCard } from "../inventory_planning/request";
import type {
  PlacedLedgerRow,
  PlacementCard,
  PlacementGuidance,
  PlacementLocation,
  PlacementNeighbor,
} from "./request";

// Placement guidance is the projection minus the placed ledger. The projection
// is invariant to placement, so it stays cached; ticking a card only refetches
// the cheap ledger and this fold reruns. Ported from the former server-side
// placement_guidance handler.
//
// A tick names a specific kind of copy (ADR 0010: finish + language are part
// of a placement's identity), so every key below includes them — otherwise a
// tick on one kind of copy would incorrectly cancel out another kind's count.

type CopyIdentity = {
  set_code: string;
  collector_number: string;
  finish: string;
  language: string;
};

const atKey = (copy: CopyIdentity, location: string): string =>
  `${copy.set_code} ${copy.collector_number} ${copy.finish} ${copy.language} ${location}`;

function indexPlacedAt(ledger: PlacedLedgerRow[]): Map<string, number> {
  const placed = new Map<string, number>();
  for (const row of ledger) {
    const key = atKey(row, row.location);
    placed.set(key, (placed.get(key) ?? 0) + row.quantity);
  }
  return placed;
}

function placedAtQty(
  placedAt: Map<string, number>,
  card: CopyIdentity,
  location_name: string,
): number {
  return placedAt.get(atKey(card, location_name)) ?? 0;
}

function neighbors(
  cards: ProjectionCard[],
  placedAt: Map<string, number>,
  location_name: string,
): PlacementNeighbor[] {
  return cards.map((card) => ({
    name: card.name,
    set_code: card.set_code,
    collector_number: card.collector_number,
    finish: card.finish,
    language: card.language,
    already_placed: placedAtQty(placedAt, card, location_name) > 0,
  }));
}

function buildLocation(
  location: InventoryProjection["locations"][number],
  placedAt: Map<string, number>,
): PlacementLocation | null {
  const cards = location.cards;
  const placementCards: PlacementCard[] = [];

  cards.forEach((card, index) => {
    const toPlace = Math.max(
      0,
      card.quantity - placedAtQty(placedAt, card, location.location_name),
    );
    if (toPlace <= 0) {
      return;
    }
    placementCards.push({
      name: card.name,
      set_code: card.set_code,
      collector_number: card.collector_number,
      finish: card.finish,
      language: card.language,
      to_place_quantity: toPlace,
      // The single card immediately before and after in cascade order: a card's
      // slot sits directly between these, so the anchor must be one of them —
      // reaching past an unplaced neighbour to a farther card points at the
      // wrong slot.
      before: neighbors(
        cards.slice(Math.max(0, index - 1), index),
        placedAt,
        location.location_name,
      ),
      after: neighbors(cards.slice(index + 1, index + 2), placedAt, location.location_name),
    });
  });

  if (placementCards.length === 0) {
    return null;
  }
  return {
    location_name: location.location_name,
    total_quantity: placementCards.reduce((sum, card) => sum + card.to_place_quantity, 0),
    cards: placementCards,
  };
}

export function buildGuidance(
  projection: InventoryProjection,
  ledger: PlacedLedgerRow[],
): PlacementGuidance {
  const placedAt = indexPlacedAt(ledger);

  const locations: PlacementLocation[] = [];
  for (const location of projection.locations) {
    const built = buildLocation(location, placedAt);
    if (built !== null) {
      locations.push(built);
    }
  }

  // The sum of what the lists below actually show — not a second definition
  // of "unplaced" computed independently, which is exactly how the header and
  // the lists used to disagree in the presence of drift (#107). A copy placed
  // somewhere the rules no longer send it is not "unplaced" by this number;
  // it's misplaced (data/placement/resort.ts), a different kind of work.
  const total_unplaced = locations.reduce((sum, location) => sum + location.total_quantity, 0);

  return { locations, total_unplaced };
}
