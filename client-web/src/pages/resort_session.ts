import type { ResortEntry, ResortWorklist } from "../data/placement/resort";

// Session state for the re-sort section: which entries/groups this session
// has already resolved (pulled out or relocated), hidden from view before the
// ledger refetch confirms it server-side — the same optimistic-before-refetch
// shape as `placement_session.ts`'s ticks, simplified because a resolved
// re-sort item has nothing useful to show struck-through; it just leaves.

export type ResortSession = { resolved: Set<string> };

export function emptyResortSession(): ResortSession {
  return { resolved: new Set() };
}

function entryKey(from_location: string, entry: ResortEntry): string {
  return `${from_location} ${entry.set_code} ${entry.collector_number} ${entry.finish} ${entry.language}`;
}

function groupKey(from_location: string): string {
  return `group ${from_location}`;
}

export function resolveEntry(
  session: ResortSession,
  from_location: string,
  entry: ResortEntry,
): ResortSession {
  return { resolved: new Set(session.resolved).add(entryKey(from_location, entry)) };
}

export function unresolveEntry(
  session: ResortSession,
  from_location: string,
  entry: ResortEntry,
): ResortSession {
  const resolved = new Set(session.resolved);
  resolved.delete(entryKey(from_location, entry));
  return { resolved };
}

// A relocate resolves the whole group at once — it re-points every row at
// `from_location`, not one entry's.
export function resolveGroup(session: ResortSession, from_location: string): ResortSession {
  return { resolved: new Set(session.resolved).add(groupKey(from_location)) };
}

export function unresolveGroup(session: ResortSession, from_location: string): ResortSession {
  const resolved = new Set(session.resolved);
  resolved.delete(groupKey(from_location));
  return { resolved };
}

// The worklist with anything this session already resolved hidden: a
// relocated group vanishes entirely, a pulled-out entry drops from its group,
// and a group emptied that way drops too. `total_misplaced` is recomputed
// from what's left so the header stays in step with what's actually shown.
export function filterResortWorklist(
  worklist: ResortWorklist,
  session: ResortSession,
): ResortWorklist {
  const groups = worklist.groups
    .filter((group) => !session.resolved.has(groupKey(group.from_location)))
    .map((group) => ({
      ...group,
      entries: group.entries.filter(
        (entry) => !session.resolved.has(entryKey(group.from_location, entry)),
      ),
    }))
    .filter((group) => group.entries.length > 0);

  const total_misplaced = groups.reduce(
    (sum, group) => sum + group.entries.reduce((entrySum, entry) => entrySum + entry.quantity, 0),
    0,
  );

  return { groups, total_misplaced };
}
