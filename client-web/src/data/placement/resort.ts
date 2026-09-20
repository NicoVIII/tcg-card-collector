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
  from_location: string;
  entries: ResortEntry[];
  // The single destination every entry in this group shares, when the group
  // vanished from the projection entirely and its drift maps to exactly one
  // place — the shape a rename leaves behind. A human-confirmed guess, never
  // proof: the group might just as well have been deleted or split.
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
  byLocation: Map<string, LocationTally>;
};

function tallyFor(
  tallies: Map<string, CopyTallies>,
  copy: CopyIdentity,
  name: string,
  location: string,
): LocationTally {
  const key = copyKey(copy);
  let entry = tallies.get(key);
  if (entry === undefined) {
    entry = { identity: copy, name, byLocation: new Map() };
    tallies.set(key, entry);
  }
  let tally = entry.byLocation.get(location);
  if (tally === undefined) {
    tally = { placed: 0, projected: 0 };
    entry.byLocation.set(location, tally);
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
      const tally = tallyFor(tallies, card, card.name, location.location_name);
      tally.projected += card.quantity;
    }
  }
  for (const row of ledger) {
    const tally = tallyFor(tallies, row, "", row.location);
    tally.placed += row.quantity;
  }

  return tallies;
}

function locationOrder(projection: InventoryProjection): Map<string, number> {
  const order = new Map<string, number>();
  projection.locations.forEach((location, index) => {
    order.set(location.location_name, index);
  });
  return order;
}

function byLocationName<T extends { location_name: string }>(
  order: Map<string, number>,
): (a: T, b: T) => number {
  return (a, b) => {
    const orderDelta =
      (order.get(a.location_name) ?? Infinity) - (order.get(b.location_name) ?? Infinity);
    return orderDelta !== 0 ? orderDelta : a.location_name.localeCompare(b.location_name);
  };
}

function destinationsFor(
  copy: CopyTallies,
  from_location: string,
  order: Map<string, number>,
): ResortDestination[] {
  const destinations: ResortDestination[] = [];
  for (const [location_name, tally] of copy.byLocation) {
    if (location_name === from_location) {
      continue;
    }
    const unplaced = Math.max(0, tally.projected - tally.placed);
    if (unplaced > 0) {
      destinations.push({ location_name, quantity: unplaced });
    }
  }
  return destinations.sort(byLocationName(order));
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
  from_location: string,
  entries: ResortEntry[],
  projection: InventoryProjection,
): string | null {
  const stillProjected = projection.locations.some(
    (location) => location.location_name === from_location,
  );
  if (stillProjected) {
    return null;
  }

  const targets = new Set<string>();
  for (const entry of entries) {
    if (entry.destinations.length !== 1) {
      return null;
    }
    targets.add(entry.destinations[0]!.location_name);
  }
  return targets.size === 1 ? [...targets][0]! : null;
}

export function buildResortWorklist(
  projection: InventoryProjection,
  ledger: PlacedLedgerRow[],
): ResortWorklist {
  const tallies = buildTallies(projection, ledger);
  const order = locationOrder(projection);

  const byFromLocation = new Map<string, ResortEntry[]>();
  let total_misplaced = 0;

  for (const copy of tallies.values()) {
    for (const [from_location, tally] of copy.byLocation) {
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
        destinations: destinationsFor(copy, from_location, order),
      };
      const entries = byFromLocation.get(from_location) ?? [];
      entries.push(entry);
      byFromLocation.set(from_location, entries);
    }
  }

  const groupOrder = (a: ResortGroup, b: ResortGroup): number => {
    const orderDelta =
      (order.get(a.from_location) ?? Infinity) - (order.get(b.from_location) ?? Infinity);
    return orderDelta !== 0 ? orderDelta : a.from_location.localeCompare(b.from_location);
  };

  const groups: ResortGroup[] = [...byFromLocation.entries()]
    .map(([from_location, entries]) => {
      const sortedEntries = entries.sort((a, b) => entrySortKey(a).localeCompare(entrySortKey(b)));
      return {
        from_location,
        entries: sortedEntries,
        looks_like_rename: renameDestination(from_location, sortedEntries, projection),
      };
    })
    .sort(groupOrder);

  return { groups, total_misplaced };
}
