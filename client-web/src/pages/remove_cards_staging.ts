import { FINISHES, LANGUAGES, type Finish, type Language } from "../data/collection/copy_kind";
import type { CollectionCopy } from "../data/collection/request";
import { claimsOn, describeClaims, freeCopies } from "../data/managed_location/claims";
import type { ManagedLocation } from "../data/managed_location/request";
import type { CardPlacementInput, PlacedLedgerRow } from "../data/placement/request";
import { type RemovalSource, sourceKey, sourcesFor } from "./remove_cards_sources";

export type EntryInput = {
  setCode: string;
  collectorNumber: string;
  finish: Finish;
  language: Language;
  quantity: number;
};

// `owned` is the collection's quantity of this copy when it was staged — what
// the row shows and what its quantity is capped by. The server re-checks at
// commit (ADR 0021), so a stale value costs a rejected removal, never a
// silent over-removal. `source` is where these copies were physically taken
// from — null until the collector picks one of several `sources`; a line is
// one (copy, source) pair.
export type StagedEntry = EntryInput & {
  owned: number;
  sources: RemovalSource[];
  source: RemovalSource | null;
};

export type RawStagedEntry = {
  setCode: string;
  collectorNumber: string;
  finish: string;
  language: string;
  quantity: number;
};

// Normalizes raw form input into a stageable entry, or null when it can't
// make a valid one. Mirrors add_cards_staging's normalizeEntry — the same
// row shape, just meaning "how many to remove" instead of "how many to add".
export function normalizeEntry(raw: RawStagedEntry): EntryInput | null {
  const setCode = raw.setCode.trim().toLowerCase();
  const collectorNumber = raw.collectorNumber.trim();
  if (setCode.length === 0 || collectorNumber.length === 0) {
    return null;
  }
  if (!Number.isInteger(raw.quantity) || raw.quantity < 1) {
    return null;
  }
  if (!FINISHES.includes(raw.finish as Finish) || !LANGUAGES.includes(raw.language as Language)) {
    return null;
  }
  return {
    setCode,
    collectorNumber,
    finish: raw.finish as Finish,
    language: raw.language as Language,
    quantity: raw.quantity,
  };
}

function sameKey(a: EntryInput, b: EntryInput): boolean {
  return (
    a.setCode === b.setCode &&
    a.collectorNumber === b.collectorNumber &&
    a.finish === b.finish &&
    a.language === b.language
  );
}

function sourceIdentity(entry: StagedEntry): string | null {
  return entry.source === null ? null : sourceKey(entry.source);
}

function sameLine(a: StagedEntry, b: StagedEntry): boolean {
  return sameKey(a, b) && sourceIdentity(a) === sourceIdentity(b);
}

function copyTotal(list: StagedEntry[], entry: EntryInput): number {
  return list
    .filter((staged) => sameKey(staged, entry))
    .reduce((sum, staged) => sum + staged.quantity, 0);
}

export type StageResult = { ok: true; list: StagedEntry[] } | { ok: false; message: string };

function describeCopy(copy: { finish: Finish; language: Language }): string {
  return `${copy.finish}·${copy.language}`;
}

function ownedQuantity(owned: CollectionCopy[], entry: EntryInput): number {
  return (
    owned.find((copy) => copy.finish === entry.finish && copy.language === entry.language)
      ?.quantity ?? 0
  );
}

function notOwnedMessage(owned: CollectionCopy[], entry: EntryInput): string {
  const key = `${entry.setCode} ${entry.collectorNumber} (${describeCopy(entry)})`;
  if (owned.length === 0) {
    return `You don't own ${key}.`;
  }
  return `You don't own ${key}; you own it as ${owned.map(describeCopy).join(", ")}.`;
}

function capMessage(ownedQty: number, alreadyStaged: number): string {
  const staged = alreadyStaged > 0 ? ` (${alreadyStaged} already staged)` : "";
  return `Only ${ownedQty} owned${staged}.`;
}

function asCopy(entry: EntryInput) {
  return {
    set_code: entry.setCode,
    collector_number: entry.collectorNumber,
    finish: entry.finish,
    language: entry.language,
  };
}

// A removal may only take copies no deck claims: cutting into a deck would
// leave it short without the user deciding that (ADR 0022). The server
// doesn't enforce this — Collection can't ask Inventory Planning — so this
// guard is the one place it's prevented.
function deckGuardMessage(entry: EntryInput, ownedQty: number, decks: ManagedLocation[]): string {
  const key = `${entry.setCode} ${entry.collectorNumber} (${describeCopy(entry)})`;
  const free = freeCopies(ownedQty, decks, asCopy(entry));
  const claims = describeClaims(claimsOn(decks, asCopy(entry)));
  return `Only ${free} of ${key} can be removed: the rest are in deck(s) ${claims}. Remove them from the deck first.`;
}

function describeSource(source: RemovalSource): string {
  return source.kind === "placed" ? `recorded in ${source.name}` : "unplaced";
}

function sourceCapMessage(entry: EntryInput, source: RemovalSource): string {
  const key = `${entry.setCode} ${entry.collectorNumber} (${describeCopy(entry)})`;
  return `Only ${source.available} of ${key} are ${describeSource(source)}; stage the rest as their own line.`;
}

function onlySource(sources: RemovalSource[]): RemovalSource | null {
  return sources.length === 1 ? sources[0] : null;
}

// Stages an entry against the card's owned copies (every kind the collection
// holds of this printing), refusing an unowned copy, a quantity above what's
// owned, or one that would cut into copies a deck holds — counting every line
// already staged for the same copy. The line's source is preselected when
// the copy can only have come from one place.
export function stageEntry(
  list: StagedEntry[],
  entry: EntryInput,
  owned: CollectionCopy[],
  decks: ManagedLocation[],
  ledger: PlacedLedgerRow[],
): StageResult {
  const ownedQty = ownedQuantity(owned, entry);
  if (ownedQty === 0) {
    return { ok: false, message: notOwnedMessage(owned, entry) };
  }
  const alreadyStaged = copyTotal(list, entry);
  if (alreadyStaged + entry.quantity > ownedQty) {
    return { ok: false, message: capMessage(ownedQty, alreadyStaged) };
  }
  const free = freeCopies(ownedQty, decks, asCopy(entry));
  if (alreadyStaged + entry.quantity > free) {
    return { ok: false, message: deckGuardMessage(entry, ownedQty, decks) };
  }
  const sources = sourcesFor(asCopy(entry), free, ledger, decks);
  const candidate: StagedEntry = {
    ...entry,
    owned: ownedQty,
    sources,
    source: onlySource(sources),
  };
  const existing = list.find((staged) => sameLine(staged, candidate));
  const staged = { ...candidate, quantity: (existing?.quantity ?? 0) + entry.quantity };
  if (staged.source !== null && staged.quantity > staged.source.available) {
    return { ok: false, message: sourceCapMessage(entry, staged.source) };
  }
  return {
    ok: true,
    list: existing ? list.map((item) => (item === existing ? staged : item)) : [...list, staged],
  };
}

// Picks where a line's copies were taken from, merging it into a line that
// already names that source for the same copy.
export function chooseSource(
  list: StagedEntry[],
  entry: StagedEntry,
  source: RemovalSource,
): StageResult {
  const chosen = { ...entry, source };
  const target = list.find((staged) => staged !== entry && sameLine(staged, chosen));
  const merged = { ...chosen, quantity: (target?.quantity ?? 0) + entry.quantity };
  if (merged.quantity > source.available) {
    return { ok: false, message: sourceCapMessage(entry, source) };
  }
  return {
    ok: true,
    list: list
      .filter((staged) => staged !== target)
      .map((staged) => (staged === entry ? merged : staged)),
  };
}

export function needsSource(entry: StagedEntry): boolean {
  return entry.source === null && entry.sources.length > 1;
}

export function printingKey(entry: EntryInput): string {
  return `${entry.setCode} ${entry.collectorNumber}`;
}

export function exceedsOwned(entry: StagedEntry): boolean {
  return entry.quantity > entry.owned;
}

function rematchSource(
  picked: RemovalSource | null,
  sources: RemovalSource[],
): RemovalSource | null {
  const only = onlySource(sources);
  if (only !== null || picked === null) {
    return only;
  }
  return sources.find((source) => sourceKey(source) === sourceKey(picked)) ?? null;
}

function refreshLine(
  entry: StagedEntry,
  copiesByPrinting: Map<string, CollectionCopy[]>,
  ledger: PlacedLedgerRow[],
  decks: ManagedLocation[],
): StagedEntry {
  const copies = copiesByPrinting.get(printingKey(entry));
  const owned = copies === undefined ? entry.owned : ownedQuantity(copies, entry);
  const sources = sourcesFor(asCopy(entry), freeCopies(owned, decks, asCopy(entry)), ledger, decks);
  return { ...entry, owned, sources, source: rematchSource(entry.source, sources) };
}

// A picked source that no longer holds what its lines take goes back to
// unpicked, so the collector chooses again against the fresh ledger.
function unpickOverdrawn(list: StagedEntry[]): StagedEntry[] {
  return list.map((entry) => {
    if (entry.source === null || entry.sources.length < 2) {
      return entry;
    }
    const drawn = list
      .filter((staged) => sameLine(staged, entry))
      .reduce((sum, staged) => sum + staged.quantity, 0);
    return drawn > entry.source.available ? { ...entry, source: null } : entry;
  });
}

function mergeLines(list: StagedEntry[]): StagedEntry[] {
  return list.reduce<StagedEntry[]>((merged, entry) => {
    const existing = merged.find((staged) => sameLine(staged, entry));
    if (existing === undefined) {
      return [...merged, entry];
    }
    const combined = { ...existing, quantity: existing.quantity + entry.quantity };
    return merged.map((staged) => (staged === existing ? combined : staged));
  }, []);
}

// Re-reads each staged line's owned quantity and sources after the server
// rejected the removal as stale, so the lines that no longer fit are the ones
// marked. Printings missing from the map keep their previous owned value.
export function refreshStaged(
  list: StagedEntry[],
  copiesByPrinting: Map<string, CollectionCopy[]>,
  ledger: PlacedLedgerRow[],
  decks: ManagedLocation[],
): StagedEntry[] {
  return mergeLines(
    unpickOverdrawn(list.map((entry) => refreshLine(entry, copiesByPrinting, ledger, decks))),
  );
}

export function staleMessage(list: StagedEntry[]): string {
  const over = list.filter(exceedsOwned).length;
  const unpicked = list.filter(needsSource).length;
  if (unpicked > 0) {
    return `The collection or its placements changed since staging: pick again where ${unpicked} row(s) were taken from.`;
  }
  if (over === 0) {
    return "The collection changed since staging; nothing staged exceeds it now — try again.";
  }
  return `The collection changed since staging: ${over} row(s) now exceed what's owned. Adjust or remove them.`;
}

export function removeEntry(list: StagedEntry[], entry: StagedEntry): StagedEntry[] {
  return list.filter((staged) => !sameLine(staged, entry));
}

export function totalCards(list: StagedEntry[]): number {
  return list.reduce((sum, entry) => sum + entry.quantity, 0);
}

export function toRemoveCardsRows(list: StagedEntry[]): Array<{
  setCode: string;
  collectorNumber: string;
  finish: Finish;
  language: Language;
  quantity: number;
}> {
  return list.map((entry) => ({
    setCode: entry.setCode,
    collectorNumber: entry.collectorNumber,
    finish: entry.finish,
    language: entry.language,
    quantity: entry.quantity,
  }));
}

// The ledger rows the removal takes copies out of — unmarked before the
// collection shrinks, so the reconcile has nothing left to guess about.
export function toUnmarkPlacements(list: StagedEntry[]): CardPlacementInput[] {
  return list.flatMap((entry) =>
    entry.source?.kind === "placed"
      ? [
          {
            set_code: entry.setCode,
            collector_number: entry.collectorNumber,
            finish: entry.finish,
            language: entry.language,
            location: entry.source.location,
            quantity: entry.quantity,
          },
        ]
      : [],
  );
}
