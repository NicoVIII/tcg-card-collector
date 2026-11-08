import { locationKey, type LocationRef } from "../inventory_planning/location_ref";
import type { InventoryProjection } from "../inventory_planning/request";
import type { Finish, Language } from "../collection/copy_kind";
import type { PlacedLedgerRow } from "./request";

// The re-sort worklist: copies the placed ledger records somewhere the
// current projection no longer sends them (#107). Ported from the same shape
// of fold as `guidance.ts` — a rule re-target or rename leaves ledger rows
// pointed at a stale location; this module pairs each stranded copy with
// where it belongs now, so the worklist can tell "pull this out and re-file
// it" apart from "nothing moved, just fix the record".

type CopyIdentity = {
  set_code: string;
  collector_number: string;
  finish: Finish;
  language: Language;
};

const copyKey = (copy: CopyIdentity): string =>
  `${copy.set_code} ${copy.collector_number} ${copy.finish} ${copy.language}`;

export type ResortDestination = {
  location: LocationRef;
  location_name: string;
  quantity: number;
};

export type ResortEntry = {
  // "" when the copy is no longer projected at any location under the
  // current rules — there is nothing left to look its name up against.
  name: string;
  set_code: string;
  collector_number: string;
  finish: Finish;
  language: Language;
  quantity: number;
  destinations: ResortDestination[];
};

export type ResortGroup = {
  from_location: LocationRef;
  from_location_key: string;
  from_location_name: string;
  entries: ResortEntry[];
  // The single cascade destination every entry in this group shares, when the
  // group is a cascade location that vanished from the projection entirely and
  // its drift maps to exactly one place — the shape a rule-target rename
  // leaves behind. A human-confirmed guess, never proof: the group might just
  // as well have been deleted or split. Never set for a managed location:
  // renaming one changes only its name, so its rows never strand this way.
  looks_like_rename: string | null;
};

export type ResortWorklist = {
  groups: ResortGroup[];
  total_misplaced: number;
};

type LocationTally = { placed: number; projected: number };

type CopyTallies = {
  identity: CopyIdentity;
  name: string;
  // Keyed by locationKey.
  byLocation: Map<string, LocationTally>;
};

// Every location either side mentions, by locationKey: its ref and display
// name. A ledger-only cascade location's name is its own key; a managed
// location is always projected (empty or not), so it always has a name.
type KnownLocation = { location: LocationRef; location_name: string };

function knownLocations(
  projection: InventoryProjection,
  ledger: PlacedLedgerRow[],
): Map<string, KnownLocation> {
  const known = new Map<string, KnownLocation>();
  for (const row of ledger) {
    known.set(locationKey(row.location), {
      location: row.location,
      location_name: row.location.key,
    });
  }
  for (const location of projection.locations) {
    known.set(locationKey(location.location), {
      location: location.location,
      location_name: location.location_name,
    });
  }
  return known;
}

function tallyFor(
  tallies: Map<string, CopyTallies>,
  copy: CopyIdentity,
  name: string,
  location_key: string,
): LocationTally {
  const key = copyKey(copy);
  let entry = tallies.get(key);
  if (entry === undefined) {
    entry = { identity: copy, name, byLocation: new Map() };
    tallies.set(key, entry);
  }
  let tally = entry.byLocation.get(location_key);
  if (tally === undefined) {
    tally = { placed: 0, projected: 0 };
    entry.byLocation.set(location_key, tally);
  }
  return tally;
}

// Every (copy, location) pair either side mentions, with how much of that
// copy is projected there and how much the ledger says is placed there.
function buildTallies(
  projection: InventoryProjection,
  ledger: PlacedLedgerRow[],
): Map<string, CopyTallies> {
  const tallies = new Map<string, CopyTallies>();

  for (const location of projection.locations) {
    for (const card of location.cards) {
      const tally = tallyFor(tallies, card, card.name, locationKey(location.location));
      tally.projected += card.quantity;
    }
  }
  for (const row of ledger) {
    const tally = tallyFor(tallies, row, "", locationKey(row.location));
    tally.placed += row.quantity;
  }

  return tallies;
}

// Projection (cascade) order by locationKey.
function locationOrder(projection: InventoryProjection): Map<string, number> {
  const order = new Map<string, number>();
  projection.locations.forEach((location, index) => {
    order.set(locationKey(location.location), index);
  });
  return order;
}

// Projection order first; locations the projection doesn't list fall back to
// their display name.
function byProjectionOrder(
  order: Map<string, number>,
  a: { key: string; name: string },
  b: { key: string; name: string },
): number {
  const orderDelta = (order.get(a.key) ?? Infinity) - (order.get(b.key) ?? Infinity);
  return orderDelta !== 0 ? orderDelta : a.name.localeCompare(b.name);
}

function destinationsFor(
  copy: CopyTallies,
  from_location_key: string,
  known: Map<string, KnownLocation>,
  order: Map<string, number>,
): ResortDestination[] {
  const destinations: ResortDestination[] = [];
  for (const [location_key, tally] of copy.byLocation) {
    if (location_key === from_location_key) {
      continue;
    }
    const unplaced = Math.max(0, tally.projected - tally.placed);
    const location = known.get(location_key);
    if (unplaced > 0 && location !== undefined) {
      destinations.push({ ...location, quantity: unplaced });
    }
  }
  return destinations.sort((a, b) =>
    byProjectionOrder(
      order,
      { key: locationKey(a.location), name: a.location_name },
      { key: locationKey(b.location), name: b.location_name },
    ),
  );
}

function entrySortKey(entry: ResortEntry): string {
  return `${entry.set_code} ${entry.collector_number} ${entry.finish} ${entry.language}`;
}

// A group "looks like a rename" only when its whole stale location vanished
// from the projection (nothing still claims that name) and every misplaced
// copy in it agrees on exactly one destination — the shape a plain rename
// leaves behind, as opposed to a predicate change that scatters copies to
// several places or leaves some with nowhere to go.
function renameDestination(
  from_location: LocationRef,
  entries: ResortEntry[],
  order: Map<string, number>,
): string | null {
  if (from_location.kind !== "cascade" || order.has(locationKey(from_location))) {
    return null;
  }

  const targets = new Set<string>();
  for (const entry of entries) {
    const only = entry.destinations.length === 1 ? entry.destinations[0]! : null;
    if (only === null || only.location.kind !== "cascade") {
      return null;
    }
    targets.add(only.location.key);
  }
  return targets.size === 1 ? [...targets][0]! : null;
}

export function buildResortWorklist(
  projection: InventoryProjection,
  ledger: PlacedLedgerRow[],
): ResortWorklist {
  const tallies = buildTallies(projection, ledger);
  const known = knownLocations(projection, ledger);
  const order = locationOrder(projection);

  const byFromLocation = new Map<string, ResortEntry[]>();
  let total_misplaced = 0;

  for (const copy of tallies.values()) {
    for (const [from_location_key, tally] of copy.byLocation) {
      const misplaced = Math.max(0, tally.placed - tally.projected);
      if (misplaced <= 0) {
        continue;
      }
      total_misplaced += misplaced;
      const entry: ResortEntry = {
        name: copy.name,
        set_code: copy.identity.set_code,
        collector_number: copy.identity.collector_number,
        finish: copy.identity.finish,
        language: copy.identity.language,
        quantity: misplaced,
        destinations: destinationsFor(copy, from_location_key, known, order),
      };
      const entries = byFromLocation.get(from_location_key) ?? [];
      entries.push(entry);
      byFromLocation.set(from_location_key, entries);
    }
  }

  const groupOrder = (a: ResortGroup, b: ResortGroup): number =>
    byProjectionOrder(
      order,
      { key: a.from_location_key, name: a.from_location_name },
      { key: b.from_location_key, name: b.from_location_name },
    );

  const groups: ResortGroup[] = [...byFromLocation.entries()]
    .map(([from_location_key, entries]) => {
      const from = known.get(from_location_key)!;
      const sortedEntries = entries.sort((a, b) => entrySortKey(a).localeCompare(entrySortKey(b)));
      return {
        from_location: from.location,
        from_location_key,
        from_location_name: from.location_name,
        entries: sortedEntries,
        looks_like_rename: renameDestination(from.location, sortedEntries, order),
      };
    })
    .sort(groupOrder);

  return { groups, total_misplaced };
}
