import { locationKey, type LocationRef } from "../inventory_planning/location_ref";

// Where an in-progress audit walk survives a reload (#108): this browser
// only, per location. Storage can be unavailable (private mode, blocked site
// data); the walk then simply doesn't survive a reload, which the page says.

const prefix = "location-audit:";

export function loadDraft(location: LocationRef): string | null {
  try {
    return localStorage.getItem(prefix + locationKey(location));
  } catch {
    return null;
  }
}

export function saveDraft(location: LocationRef, serialized: string): boolean {
  try {
    localStorage.setItem(prefix + locationKey(location), serialized);
    return true;
  } catch {
    return false;
  }
}

export function clearDraft(location: LocationRef): void {
  try {
    localStorage.removeItem(prefix + locationKey(location));
  } catch {
    // Nothing to clear when storage is unavailable.
  }
}

export function hasDraft(location: LocationRef): boolean {
  return loadDraft(location) !== null;
}
