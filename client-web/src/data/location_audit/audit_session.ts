import { copyIdentityKey, type CopyIdentity } from "../collection/copy_kind";
import { locationKey, type LocationRef } from "../inventory_planning/location_ref";
import type { PlacedLedgerRow } from "../placement/request";
import { type AuditRow, placedTotal } from "./audit_list";
import type { CompleteLocationAuditInput } from "./request";

// One walk over a location, held in the page until it completes (ADR 0024):
// nothing is written before then, so abandoning is just dropping the session.

// A copy found that the ledger doesn't record at the audited location.
// `in_collection` false means it was never imported: reported, never sent.
export type UnexpectedFind = {
  copy: CopyIdentity;
  quantity: number;
  in_collection: boolean;
  source: LocationRef | null;
};

export type AuditSession = {
  found: ReadonlyMap<string, number>;
  unexpected: readonly UnexpectedFind[];
};

export function emptyAuditSession(): AuditSession {
  return { found: new Map(), unexpected: [] };
}

export function foundCount(session: AuditSession, copy: CopyIdentity): number {
  return session.found.get(copyIdentityKey(copy)) ?? 0;
}

// The page's controls only offer 0..recorded: more found than recorded is an
// unexpected find, entered separately.
export function setFound(session: AuditSession, row: AuditRow, count: number): AuditSession {
  if (!Number.isInteger(count) || count < 0 || count > row.recorded) {
    throw new RangeError(`found count ${count} outside 0..${row.recorded}`);
  }
  const found = new Map(session.found);
  found.set(copyIdentityKey(row), count);
  return { ...session, found };
}

export function addUnexpected(session: AuditSession, find: UnexpectedFind): AuditSession {
  return { ...session, unexpected: [...session.unexpected, find] };
}

export function removeUnexpected(session: AuditSession, index: number): AuditSession {
  return { ...session, unexpected: session.unexpected.filter((_, at) => at !== index) };
}

export function setUnexpectedSource(
  session: AuditSession,
  index: number,
  source: LocationRef | null,
): AuditSession {
  return {
    ...session,
    unexpected: session.unexpected.map((find, at) => (at === index ? { ...find, source } : find)),
  };
}

export function missingRows(session: AuditSession, rows: AuditRow[]): AuditRow[] {
  return rows
    .map((row) => ({ ...row, recorded: row.recorded - foundCount(session, row) }))
    .filter((row) => row.recorded > 0);
}

export function reportOnly(session: AuditSession): UnexpectedFind[] {
  return session.unexpected.filter((find) => !find.in_collection);
}

function recordedAt(ledger: PlacedLedgerRow[], copy: CopyIdentity, location: LocationRef): number {
  const key = copyIdentityKey(copy);
  return ledger
    .filter(
      (row) => copyIdentityKey(row) === key && locationKey(row.location) === locationKey(location),
    )
    .reduce((sum, row) => sum + row.quantity, 0);
}

// Map.groupBy is ES2024; the lib target is ES2023.
function groupBy<T>(items: T[], keyOf: (item: T) => string): Map<string, T[]> {
  const groups = new Map<string, T[]>();
  for (const item of items) {
    const key = keyOf(item);
    groups.set(key, [...(groups.get(key) ?? []), item]);
  }
  return groups;
}

function sumQuantities(finds: UnexpectedFind[]): number {
  return finds.reduce((sum, find) => sum + find.quantity, 0);
}

// Whether every in-collection find of this copy can be applied: those without
// a source must fit in what isn't placed anywhere yet, and those moving from
// a source can't take more than the ledger records there. The server checks
// the same, so this only keeps the user from a request it would reject.
function copyResolves(
  finds: UnexpectedFind[],
  owned: ReadonlyMap<string, number>,
  ledger: PlacedLedgerRow[],
): boolean {
  const copy = finds[0].copy;
  const unsourced = finds.filter((find) => find.source === null);
  const available = (owned.get(copyIdentityKey(copy)) ?? 0) - placedTotal(ledger, copy);
  if (sumQuantities(unsourced) > available) {
    return false;
  }
  const bySource = groupBy(
    finds.filter((find) => find.source !== null),
    (find) => locationKey(find.source as LocationRef),
  );
  return [...bySource.values()].every(
    (group) => sumQuantities(group) <= recordedAt(ledger, copy, group[0].source as LocationRef),
  );
}

// The copies whose finds still need a (different) source before the audit
// can complete.
export function unresolvedCopies(
  session: AuditSession,
  owned: ReadonlyMap<string, number>,
  ledger: PlacedLedgerRow[],
): Set<string> {
  const byCopy = groupBy(
    session.unexpected.filter((find) => find.in_collection),
    (find) => copyIdentityKey(find.copy),
  );
  return new Set(
    [...byCopy.entries()]
      .filter(([, finds]) => !copyResolves(finds, owned, ledger))
      .map(([key]) => key),
  );
}

export function toRequest(
  location: LocationRef,
  session: AuditSession,
  rows: AuditRow[],
): CompleteLocationAuditInput {
  return {
    location,
    missing: missingRows(session, rows).map((row) => ({
      set_code: row.set_code,
      collector_number: row.collector_number,
      finish: row.finish,
      language: row.language,
      quantity: row.recorded,
    })),
    unexpected: session.unexpected
      .filter((find) => find.in_collection)
      .map((find) => ({ copy: { ...find.copy, quantity: find.quantity }, source: find.source })),
  };
}

type StoredSession = {
  found: [string, number][];
  unexpected: UnexpectedFind[];
};

export function serializeSession(session: AuditSession): string {
  const stored: StoredSession = {
    found: [...session.found.entries()],
    unexpected: [...session.unexpected],
  };
  return JSON.stringify(stored);
}

function isStoredSession(value: unknown): value is StoredSession {
  const candidate = value as StoredSession | null;
  return (
    typeof candidate === "object" &&
    candidate !== null &&
    Array.isArray(candidate.found) &&
    Array.isArray(candidate.unexpected)
  );
}

export type RestoreOutcome =
  | { kind: "restored"; session: AuditSession }
  | { kind: "unreadable" }
  | { kind: "stale" };

// A walk saved before a reload (#108). It is only good while every found
// count still fits what the ledger records; once the ledger moved under it
// (another tab placed or unmarked copies here), the counts no longer mean
// what they did, so the walk is dropped and the user told, never trimmed.
export function restoreSession(raw: string, rows: AuditRow[]): RestoreOutcome {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return { kind: "unreadable" };
  }
  if (!isStoredSession(parsed)) {
    return { kind: "unreadable" };
  }
  const recorded = new Map(rows.map((row) => [copyIdentityKey(row), row.recorded]));
  const fits = parsed.found.every(
    ([key, count]) => Number.isInteger(count) && count >= 0 && count <= (recorded.get(key) ?? 0),
  );
  if (!fits) {
    return { kind: "stale" };
  }
  return {
    kind: "restored",
    session: { found: new Map(parsed.found), unexpected: parsed.unexpected },
  };
}
