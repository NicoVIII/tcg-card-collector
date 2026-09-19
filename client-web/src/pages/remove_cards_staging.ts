import { FINISHES, LANGUAGES, type Finish, type Language } from "../data/collection/copy_kind";

export type StagedEntry = {
  setCode: string;
  collectorNumber: string;
  finish: Finish;
  language: Language;
  quantity: number;
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
export function normalizeEntry(raw: RawStagedEntry): StagedEntry | null {
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

function sameKey(a: StagedEntry, b: StagedEntry): boolean {
  return (
    a.setCode === b.setCode &&
    a.collectorNumber === b.collectorNumber &&
    a.finish === b.finish &&
    a.language === b.language
  );
}

// Appends an entry, summing quantities when its card is already staged in the
// same kind of copy so the list always holds one line per (card, finish,
// language).
export function addEntry(list: StagedEntry[], entry: StagedEntry): StagedEntry[] {
  if (list.some((staged) => sameKey(staged, entry))) {
    return list.map((staged) =>
      sameKey(staged, entry) ? { ...staged, quantity: staged.quantity + entry.quantity } : staged,
    );
  }
  return [...list, entry];
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
