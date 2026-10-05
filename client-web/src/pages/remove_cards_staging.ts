import { FINISHES, LANGUAGES, type Finish, type Language } from "../data/collection/copy_kind";
import type { CollectionCopy } from "../data/collection/request";

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
// silent over-removal.
export type StagedEntry = EntryInput & { owned: number };

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

// Stages an entry against the card's owned copies (every kind the collection
// holds of this printing), refusing an unowned copy or a quantity above what's
// owned — counting what's already staged for the same copy, so the list holds
// one line per (card, finish, language).
export function stageEntry(
  list: StagedEntry[],
  entry: EntryInput,
  owned: CollectionCopy[],
): StageResult {
  const ownedQty = ownedQuantity(owned, entry);
  if (ownedQty === 0) {
    return { ok: false, message: notOwnedMessage(owned, entry) };
  }
  const existing = list.find((staged) => sameKey(staged, entry));
  const alreadyStaged = existing?.quantity ?? 0;
  if (alreadyStaged + entry.quantity > ownedQty) {
    return { ok: false, message: capMessage(ownedQty, alreadyStaged) };
  }
  const staged = { ...entry, quantity: alreadyStaged + entry.quantity, owned: ownedQty };
  return {
    ok: true,
    list: existing ? list.map((item) => (item === existing ? staged : item)) : [...list, staged],
  };
}

export function printingKey(entry: EntryInput): string {
  return `${entry.setCode} ${entry.collectorNumber}`;
}

export function exceedsOwned(entry: StagedEntry): boolean {
  return entry.quantity > entry.owned;
}

// Re-reads each staged row's owned quantity after the server rejected the
// removal as stale, so the rows that no longer fit are the ones marked.
// Printings missing from the map keep their previous value.
export function refreshOwned(
  list: StagedEntry[],
  copiesByPrinting: Map<string, CollectionCopy[]>,
): StagedEntry[] {
  return list.map((entry) => {
    const owned = copiesByPrinting.get(printingKey(entry));
    return owned === undefined ? entry : { ...entry, owned: ownedQuantity(owned, entry) };
  });
}

export function staleMessage(list: StagedEntry[]): string {
  const over = list.filter(exceedsOwned).length;
  if (over === 0) {
    return "The collection changed since staging; nothing staged exceeds it now — try again.";
  }
  return `The collection changed since staging: ${over} row(s) now exceed what's owned. Adjust or remove them.`;
}

export function removeEntry(list: StagedEntry[], entry: StagedEntry): StagedEntry[] {
  return list.filter((staged) => !sameKey(staged, entry));
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
