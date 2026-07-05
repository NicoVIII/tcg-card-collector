export type StagedEntry = {
  setCode: string;
  collectorNumber: string;
  quantity: number;
};

// Normalizes raw form input into a stageable entry, or null when it can't
// make a valid one. Set codes are lowercased to match catalog card keys.
export function normalizeEntry(raw: StagedEntry): StagedEntry | null {
  const setCode = raw.setCode.trim().toLowerCase();
  const collectorNumber = raw.collectorNumber.trim();
  if (setCode.length === 0 || collectorNumber.length === 0) {
    return null;
  }
  if (!Number.isInteger(raw.quantity) || raw.quantity < 1) {
    return null;
  }
  return { setCode, collectorNumber, quantity: raw.quantity };
}

function sameKey(a: StagedEntry, b: StagedEntry): boolean {
  return a.setCode === b.setCode && a.collectorNumber === b.collectorNumber;
}

// Appends an entry, summing quantities when its card is already staged so
// the list always holds one line per card.
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

export function toAddCardsRows(
  list: StagedEntry[],
): Array<{ setCode: string; collectorNumber: string; quantity: number }> {
  return list.map((entry) => ({
    setCode: entry.setCode,
    collectorNumber: entry.collectorNumber,
    quantity: entry.quantity,
  }));
}
