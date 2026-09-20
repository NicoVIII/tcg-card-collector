import type { PlacementCard, PlacementNeighbor } from "../data/placement/request";

// Session state for the placement page. Ticking a card marks it placed, which
// drops it from the next guidance refetch — but we keep showing it struck-
// through in place until the user moves on, so the list doesn't jump under their
// hands. The session remembers each ticked card and where it sat so it can be
// re-inserted at that spot.

type TickedEntry = {
  location_name: string;
  card: PlacementCard;
  index: number;
};

export type PlacementSession = {
  ticked: Record<string, TickedEntry>;
};

export function emptySession(): PlacementSession {
  return { ticked: {} };
}

// A tick names a specific kind of copy (ADR 0010): the finish and language are
// part of the identity, alongside the printing and the location.
type CopyIdentity = {
  set_code: string;
  collector_number: string;
  finish: string;
  language: string;
};

function entryKey(location_name: string, card: CopyIdentity): string {
  return `${location_name} ${card.set_code} ${card.collector_number} ${card.finish} ${card.language}`;
}

export function isTicked(
  session: PlacementSession,
  location_name: string,
  card: CopyIdentity,
): boolean {
  return entryKey(location_name, card) in session.ticked;
}

export function tick(
  session: PlacementSession,
  location_name: string,
  card: PlacementCard,
  index: number,
): PlacementSession {
  return {
    ticked: {
      ...session.ticked,
      [entryKey(location_name, card)]: { location_name, card, index },
    },
  };
}

export function untick(
  session: PlacementSession,
  location_name: string,
  card: CopyIdentity,
): PlacementSession {
  const key = entryKey(location_name, card);
  if (!(key in session.ticked)) {
    return session;
  }
  const ticked = { ...session.ticked };
  delete ticked[key];
  return { ticked };
}

// The cards a "Mark all placed" tap struck, remembered so the action can be
// undone as a single unit rather than one row at a time.
export type MarkAllBatch = { location_name: string; cards: PlacementCard[] };

// Ticks every not-yet-struck entry in a location at its current index, or
// returns null when there was nothing left to mark (so the caller can skip
// the mutation and the undo offer both).
export function tickAll(
  session: PlacementSession,
  location_name: string,
  cards: PlacementCard[],
): { session: PlacementSession; batch: MarkAllBatch } | null {
  let next = session;
  const batchCards: PlacementCard[] = [];
  cards.forEach((card, index) => {
    if (isTicked(session, location_name, card)) return;
    next = tick(next, location_name, card, index);
    batchCards.push(card);
  });
  if (batchCards.length === 0) {
    return null;
  }
  return { session: next, batch: { location_name, cards: batchCards } };
}

export function untickAll(session: PlacementSession, batch: MarkAllBatch): PlacementSession {
  return batch.cards.reduce((acc, card) => untick(acc, batch.location_name, card), session);
}

// Puts the tick state of exactly these copies back the way `before` had it,
// leaving every other entry in `current` alone — a failed mutation must not
// discard ticks the user made while it was in flight. The inverse of both
// tick/untick and tickAll/untickAll for a failed optimistic update.
export function restoreTicks(
  current: PlacementSession,
  before: PlacementSession,
  location_name: string,
  cards: CopyIdentity[],
): PlacementSession {
  return cards.reduce((acc, card) => {
    const key = entryKey(location_name, card);
    const priorEntry = before.ticked[key];
    if (priorEntry === undefined) {
      const ticked = { ...acc.ticked };
      delete ticked[key];
      return { ticked };
    }
    return { ticked: { ...acc.ticked, [key]: priorEntry } };
  }, current);
}

export function tickedLocationNames(session: PlacementSession): string[] {
  const names = new Set<string>();
  for (const entry of Object.values(session.ticked)) {
    names.add(entry.location_name);
  }
  return [...names];
}

// Re-inserts the session's struck cards into a location's fresh guidance cards
// at their recorded positions, so a just-ticked card stays visible in place.
// Whether a returned card is struck is not stored here — it's asked of the
// session per-row (isTicked) — so a card guidance still lists keeps the exact
// object reference it arrived with. That reference stability is what lets
// `<For>` skip rebuilding rows a tick didn't touch (#105).
export function mergeLocationCards(
  session: PlacementSession,
  location_name: string,
  cards: PlacementCard[],
): PlacementCard[] {
  const merged = cards.slice();

  const freshKeys = new Set(cards.map((card) => entryKey(location_name, card)));
  const strayTicks = Object.values(session.ticked)
    .filter((entry) => entry.location_name === location_name)
    .filter((entry) => !freshKeys.has(entryKey(location_name, entry.card)))
    .sort((a, b) => a.index - b.index);

  for (const entry of strayTicks) {
    const at = Math.min(Math.max(entry.index, 0), merged.length);
    merged.splice(at, 0, entry.card);
  }

  return merged;
}

function neighborLabel(neighbor: PlacementNeighbor): string {
  return neighbor.name === "" ? `${neighbor.set_code} ${neighbor.collector_number}` : neighbor.name;
}

function placedAnchorLabel(
  session: PlacementSession,
  location_name: string,
  before: PlacementNeighbor | undefined,
  after: PlacementNeighbor | undefined,
): string | null {
  // A neighbour reads as placed either because the ledger already says so, or
  // because this session ticked it — the card is in the binder either way,
  // which is what the hint promises the user (ux-design: anchor on cards the
  // user can physically see). Without the session check, ticking a card would
  // make the very next card's hint regress to the weaker unplaced fallback
  // until the ledger refetch landed — and #105 stops that refetch. Written as
  // `x !== undefined && ...` rather than a helper so TS's control-flow
  // narrowing carries through to the neighborLabel(before/after) calls below.
  const beforePlaced =
    before !== undefined && (before.already_placed || isTicked(session, location_name, before));
  const afterPlaced =
    after !== undefined && (after.already_placed || isTicked(session, location_name, after));

  if (beforePlaced && afterPlaced) {
    return `Goes between ${neighborLabel(before)} and ${neighborLabel(after)}.`;
  }
  if (beforePlaced) {
    return `Goes right after ${neighborLabel(before)}.`;
  }
  if (afterPlaced) {
    return `Goes right before ${neighborLabel(after)}.`;
  }
  return null;
}

function unplacedAnchorLabel(
  before: PlacementNeighbor | undefined,
  after: PlacementNeighbor | undefined,
): string {
  if (before && after) {
    return `Goes between ${neighborLabel(before)} and ${neighborLabel(after)} — both still to place.`;
  }
  if (before) {
    return `Goes after ${neighborLabel(before)} — also still to place.`;
  }
  if (after) {
    return `Goes before ${neighborLabel(after)} — also still to place.`;
  }

  return "Only card to place here.";
}

// A short human hint for where a card goes, anchored on its immediate cascade
// neighbours. The slot sits directly between the card before and the card after,
// so we anchor only on those — reaching past an unplaced neighbour to a farther
// placed card would point at the wrong slot and give every card in a run of
// consecutive unplaced cards the same hint. A placed neighbour is preferred as
// the anchor when present, since it is physically there to find.
export function betweenLabel(
  session: PlacementSession,
  location_name: string,
  card: PlacementCard,
): string {
  const before = card.before[0];
  const after = card.after[0];
  return (
    placedAnchorLabel(session, location_name, before, after) ?? unplacedAnchorLabel(before, after)
  );
}
