import { copyIdentityKey, type CopyIdentity } from "../collection/copy_kind";
import { locationKey, type LocationRef } from "../inventory_planning/location_ref";
import type { InventoryProjection } from "../inventory_planning/request";
import type { PlacedLedgerRow } from "../placement/request";

// What a location audit walks (#108): the placed ledger's claim for one
// location, folded against the projection for names and physical order.

// One kind of copy the ledger records at the audited location. `name` is ""
// when the projection no longer holds the copy anywhere (it left the
// collection, and ReconcilePlacedLedger hasn't caught up).
export type AuditRow = CopyIdentity & { name: string; recorded: number };

export type AuditableLocation = {
  location: LocationRef;
  location_name: string;
  recorded_total: number;
};

// Where a misfiled copy could have come from: another location the ledger
// records it at, and how many.
export type SourceCandidate = {
  location: LocationRef;
  location_name: string;
  quantity: number;
};

function sameLocation(a: LocationRef, b: LocationRef): boolean {
  return locationKey(a) === locationKey(b);
}

function cardNames(projection: InventoryProjection): Map<string, string> {
  return new Map(
    projection.locations.flatMap((location) =>
      location.cards.map((card) => [copyIdentityKey(card), card.name] as const),
    ),
  );
}

// Position of each copy in the location's projected order — the order a
// cascade location's physical stack is sorted in.
function projectedOrder(
  projection: InventoryProjection,
  location: LocationRef,
): Map<string, number> {
  const projected = projection.locations.find((candidate) =>
    sameLocation(candidate.location, location),
  );
  return new Map((projected?.cards ?? []).map((card, index) => [copyIdentityKey(card), index]));
}

function compareCopies(a: CopyIdentity, b: CopyIdentity): number {
  return copyIdentityKey(a).localeCompare(copyIdentityKey(b));
}

function compareByOrder(order: Map<string, number>) {
  return (a: AuditRow, b: AuditRow): number => {
    const aIndex = order.get(copyIdentityKey(a));
    const bIndex = order.get(copyIdentityKey(b));
    if (aIndex !== undefined && bIndex !== undefined) {
      return aIndex - bIndex;
    }
    if (aIndex !== undefined) {
      return -1;
    }
    if (bIndex !== undefined) {
      return 1;
    }
    return compareCopies(a, b);
  };
}

// The ledger's rows at `location`, in projected order; copies the projection
// no longer sends here (Misplaced) follow at the end, since they are where
// the stack is least likely to hold them in order.
export function buildAuditRows(
  location: LocationRef,
  projection: InventoryProjection,
  ledger: PlacedLedgerRow[],
): AuditRow[] {
  const names = cardNames(projection);
  return ledger
    .filter((row) => sameLocation(row.location, location))
    .map((row) => ({
      set_code: row.set_code,
      collector_number: row.collector_number,
      finish: row.finish,
      language: row.language,
      name: names.get(copyIdentityKey(row)) ?? "",
      recorded: row.quantity,
    }))
    .sort(compareByOrder(projectedOrder(projection, location)));
}

function recordedTotals(ledger: PlacedLedgerRow[]): Map<string, number> {
  const totals = new Map<string, number>();
  for (const row of ledger) {
    const key = locationKey(row.location);
    totals.set(key, (totals.get(key) ?? 0) + row.quantity);
  }
  return totals;
}

// Every location worth auditing: each projected one in projection order,
// then any the ledger still records copies at that the projection no longer
// has (a re-targeted rule's old name), so their contents can be checked too.
export function auditableLocations(
  projection: InventoryProjection,
  ledger: PlacedLedgerRow[],
): AuditableLocation[] {
  const totals = recordedTotals(ledger);
  const projected = projection.locations.map((location) => ({
    location: location.location,
    location_name: location.location_name,
    recorded_total: totals.get(locationKey(location.location)) ?? 0,
  }));
  const projectedKeys = new Set(projected.map((entry) => locationKey(entry.location)));
  const stale = new Map<string, AuditableLocation>();
  for (const row of ledger) {
    const key = locationKey(row.location);
    if (!projectedKeys.has(key) && !stale.has(key)) {
      stale.set(key, {
        location: row.location,
        location_name: row.location.key,
        recorded_total: totals.get(key) ?? 0,
      });
    }
  }
  return [...projected, ...stale.values()];
}

// Owned quantity per kind of copy. The projection places every owned copy
// exactly once (managed locations first, then the cascade down to bulk).
export function ownedQuantities(projection: InventoryProjection): Map<string, number> {
  const owned = new Map<string, number>();
  for (const location of projection.locations) {
    for (const card of location.cards) {
      const key = copyIdentityKey(card);
      owned.set(key, (owned.get(key) ?? 0) + card.quantity);
    }
  }
  return owned;
}

export function placedTotal(ledger: PlacedLedgerRow[], copy: CopyIdentity): number {
  const key = copyIdentityKey(copy);
  return ledger
    .filter((row) => copyIdentityKey(row) === key)
    .reduce((sum, row) => sum + row.quantity, 0);
}

export function sourceCandidates(
  copy: CopyIdentity,
  audited: LocationRef,
  ledger: PlacedLedgerRow[],
  locations: AuditableLocation[],
): SourceCandidate[] {
  const key = copyIdentityKey(copy);
  const names = new Map(
    locations.map((entry) => [locationKey(entry.location), entry.location_name]),
  );
  return ledger
    .filter((row) => copyIdentityKey(row) === key && !sameLocation(row.location, audited))
    .map((row) => ({
      location: row.location,
      location_name: names.get(locationKey(row.location)) ?? row.location.key,
      quantity: row.quantity,
    }));
}
