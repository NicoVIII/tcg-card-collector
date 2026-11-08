import type { ManagedLocation } from "./request";

// How decks claim owned copies — a pure fold over the cached deck list, so
// the Collection page's removal guard and the Decks page's add check agree
// with each other and with the server's own rule (ADR 0022: a copy is free
// when owned minus every deck's claims leaves some over).

type CopyIdentity = {
  set_code: string;
  collector_number: string;
  finish: string;
  language: string;
};

export type DeckClaim = { deck_name: string; quantity: number };

function sameCopy(a: CopyIdentity, b: CopyIdentity): boolean {
  return (
    a.set_code === b.set_code &&
    a.collector_number === b.collector_number &&
    a.finish === b.finish &&
    a.language === b.language
  );
}

export function claimsOn(decks: ManagedLocation[], copy: CopyIdentity): DeckClaim[] {
  return decks.flatMap((deck) =>
    deck.members
      .filter((member) => sameCopy(member, copy))
      .map((member) => ({ deck_name: deck.name, quantity: member.quantity })),
  );
}

export function claimedTotal(decks: ManagedLocation[], copy: CopyIdentity): number {
  return claimsOn(decks, copy).reduce((sum, claim) => sum + claim.quantity, 0);
}

// Owned minus every deck's claims, never below zero — when decks already
// claim more than is owned (a shortfall), nothing is free.
export function freeCopies(owned: number, decks: ManagedLocation[], copy: CopyIdentity): number {
  return Math.max(0, owned - claimedTotal(decks, copy));
}

export function describeClaims(claims: DeckClaim[]): string {
  return claims.map((claim) => `${claim.deck_name} (${claim.quantity})`).join(", ");
}
