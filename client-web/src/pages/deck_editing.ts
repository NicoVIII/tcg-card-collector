import type { CollectionCopy } from "../data/collection/request";
import { locationKey, managedLocation } from "../data/inventory_planning/location_ref";
import type { InventoryProjection, ProjectionCard } from "../data/inventory_planning/request";
import { freeCopies } from "../data/managed_location/claims";
import type { ManagedCopy, ManagedLocation } from "../data/managed_location/request";
import type { EntryInput } from "./remove_cards_staging";

// Derivations for the Decks page: a deck's rows joined with which members
// the projection says are missing, and the check an addition must pass
// before it's sent. Card names come from the catalog per row, not from the
// projection — a projection refetch after every edit would otherwise leave
// a just-added row nameless for a moment.

export type DeckRow = ManagedCopy & {
  // Copies the collection can't supply right now (ADR 0022's shortfall).
  missing: number;
};

const copyKey = (copy: {
  set_code: string;
  collector_number: string;
  finish: string;
  language: string;
}): string => `${copy.set_code} ${copy.collector_number} ${copy.finish} ${copy.language}`;

function projectedLocation(projection: InventoryProjection | undefined, deck: ManagedLocation) {
  const key = locationKey(managedLocation(deck.id));
  return projection?.locations.find((location) => locationKey(location.location) === key);
}

function missingByCopy(cards: ProjectionCard[]): Map<string, number> {
  return new Map(cards.map((card) => [copyKey(card), card.quantity]));
}

// One row per member, in the server's own key order.
export function deckRows(
  deck: ManagedLocation,
  projection: InventoryProjection | undefined,
): DeckRow[] {
  const missing = missingByCopy(projectedLocation(projection, deck)?.shortfall ?? []);
  return deck.members.map((member) => ({
    ...member,
    missing: missing.get(copyKey(member)) ?? 0,
  }));
}

export function deckRowKey(row: DeckRow): string {
  return `${row.set_code} ${row.collector_number} (${row.finish}·${row.language})`;
}

export function deckSummary(rows: DeckRow[]): string {
  const cards = rows.reduce((sum, row) => sum + row.quantity, 0);
  const missing = rows.reduce((sum, row) => sum + row.missing, 0);
  return missing > 0 ? `${cards} card(s), ${missing} missing` : `${cards} card(s)`;
}

function ownedQuantity(owned: CollectionCopy[], entry: EntryInput): number {
  return (
    owned.find((copy) => copy.finish === entry.finish && copy.language === entry.language)
      ?.quantity ?? 0
  );
}

// The server rejects the same thing (ADR 0021); checking first turns a stale
// 400 into a message naming the numbers before anything is sent.
export function additionProblem(
  entry: EntryInput,
  owned: CollectionCopy[],
  decks: ManagedLocation[],
): string | null {
  const copy = {
    set_code: entry.setCode,
    collector_number: entry.collectorNumber,
    finish: entry.finish,
    language: entry.language,
  };
  const key = `${entry.setCode} ${entry.collectorNumber} (${entry.finish}·${entry.language})`;
  const ownedQty = ownedQuantity(owned, entry);
  if (ownedQty === 0) {
    return `You don't own ${key}.`;
  }
  if (entry.quantity > ownedQty) {
    return `You own only ${ownedQty} of ${key}.`;
  }
  const free = freeCopies(ownedQty, decks, copy);
  if (entry.quantity > free) {
    return `Only ${free} of your ${ownedQty} ${key} aren't already in a deck.`;
  }
  return null;
}

export function toManagedCopy(entry: EntryInput): ManagedCopy {
  return {
    set_code: entry.setCode,
    collector_number: entry.collectorNumber,
    finish: entry.finish,
    language: entry.language,
    quantity: entry.quantity,
  };
}
