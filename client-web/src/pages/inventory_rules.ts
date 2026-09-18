import type { InventoryRule } from "../data/inventory_planning/request";

// Rule-editing helpers extracted from inventory_page.tsx so they run in the
// node test environment (client-web/AGENTS.md's "pages own JSX only" rule).

export type RuleDraft = {
  location_name: string;
  expression: string;
  selector: string;
  sort_keys: string;
};

export function draftOf(rule: InventoryRule): RuleDraft {
  return {
    location_name: rule.location_name,
    expression: rule.expression,
    selector: rule.selector,
    sort_keys: rule.sort_keys,
  };
}

// Keeps identity (id) and cascade order (position) untouched — editing a
// rule's fields never reorders it.
export function applyDraft(rule: InventoryRule, draft: RuleDraft): InventoryRule {
  return { ...rule, ...draft };
}

export function emptyDraft(): RuleDraft {
  return { location_name: "", expression: "", selector: "all", sort_keys: "" };
}

// A new rule appends after the current cascade instead of racing every other
// rule for position 0 — the trap the hand-typed Position input used to set.
export function nextPosition(rules: InventoryRule[]): number {
  return rules.reduce((max, rule) => Math.max(max, rule.position + 1), 0);
}

function indexOf(rules: InventoryRule[], id: string): number {
  return rules.findIndex((rule) => rule.id === id);
}

// Whether the rule at `id` has a neighbour in the `offset` direction to swap
// with — false at either edge of the list, or if the id isn't listed at all.
export function isMovable(rules: InventoryRule[], id: string, offset: -1 | 1): boolean {
  const index = indexOf(rules, id);
  if (index === -1) {
    return false;
  }
  const target = index + offset;
  return target >= 0 && target < rules.length;
}

// The id order after swapping the rule at `id` with its `offset` neighbour in
// the current list order — the whole cascade, ready to send to
// ReorderInventoryRules. Returns the unchanged order at an edge or an
// unlisted id, so a caller can send it as a no-op rather than special-casing
// the edges itself.
export function movedOrder(rules: InventoryRule[], id: string, offset: -1 | 1): string[] {
  const ids = rules.map((rule) => rule.id);
  const index = indexOf(rules, id);
  const target = index + offset;
  if (index === -1 || target < 0 || target >= ids.length) {
    return ids;
  }
  const reordered = [...ids];
  [reordered[index], reordered[target]] = [reordered[target], reordered[index]];
  return reordered;
}
