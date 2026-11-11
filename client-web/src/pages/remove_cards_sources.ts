import { claimedTotal } from "../data/managed_location/claims";
import type { ManagedLocation } from "../data/managed_location/request";
import { locationKey, type LocationRef } from "../data/inventory_planning/location_ref";
import type { PlacedLedgerRow } from "../data/placement/request";

// Where a removed copy can physically come from. Naming it lets the removal
// unmark that location before the collection shrinks, so the ledger's
// reconcile finds no excess to prune by its arbitrary tie-break (ADR 0023).
export type RemovalSource =
  | { kind: "placed"; location: LocationRef; name: string; available: number }
  | { kind: "unplaced"; available: number };

type CopyIdentity = {
  set_code: string;
  collector_number: string;
  finish: string;
  language: string;
};

export function sourceKey(source: RemovalSource): string {
  return source.kind === "placed" ? locationKey(source.location) : "unplaced";
}

function sameCopy(row: PlacedLedgerRow, copy: CopyIdentity): boolean {
  return (
    row.set_code === copy.set_code &&
    row.collector_number === copy.collector_number &&
    row.finish === copy.finish &&
    row.language === copy.language
  );
}

// A deck's placed copies are removable only beyond what its membership still
// claims — the claimed ones are guarded (ADR 0022); the rest sit in the deck
// physically but are free.
function placedSource(
  row: PlacedLedgerRow,
  copy: CopyIdentity,
  decks: ManagedLocation[],
): RemovalSource {
  if (row.location.kind === "cascade") {
    return {
      kind: "placed",
      location: row.location,
      name: row.location.key,
      available: row.quantity,
    };
  }
  const deck = decks.find((candidate) => candidate.id === row.location.key);
  const claimed = deck === undefined ? 0 : claimedTotal([deck], copy);
  return {
    kind: "placed",
    location: row.location,
    name: deck?.name ?? row.location.key,
    available: Math.max(0, row.quantity - claimed),
  };
}

// Every place `free` (the copy's removable quantity) can come from: the
// ledger's locations, then whatever no location records — floored at zero
// like Unplaced everywhere else. No source offers more than is free.
export function sourcesFor(
  copy: CopyIdentity,
  free: number,
  ledger: PlacedLedgerRow[],
  decks: ManagedLocation[],
): RemovalSource[] {
  const placed = ledger
    .filter((row) => sameCopy(row, copy))
    .map((row) => placedSource(row, copy, decks));
  const placedTotal = placed.reduce((sum, source) => sum + source.available, 0);
  const unplaced: RemovalSource = { kind: "unplaced", available: Math.max(0, free - placedTotal) };
  return [...placed, unplaced]
    .map((source) => ({ ...source, available: Math.min(source.available, free) }))
    .filter((source) => source.available > 0);
}
