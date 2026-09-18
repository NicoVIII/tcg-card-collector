import { createSignal } from "solid-js";
import { mapError } from "../data/http/error";

// One mutation error at a time, tagged with the form that caused it, so a
// failed save renders next to that form (role="alert") instead of clobbering
// or being clobbered by an unrelated form's error on the same page — the
// `onError: (error) => setX(mapError(error).message)` pattern that had
// accreted a fourth copy in inventory_page.tsx (client-web/AGENTS.md's
// "page plumbing that repeats" note).
export function createMutationError() {
  const [error, setError] = createSignal<{ scope: string | undefined; message: string } | null>(
    null,
  );

  const report = (caught: unknown, scope?: string) => {
    setError({ scope, message: mapError(caught).message });
  };

  const clear = () => setError(null);

  const messageFor = (scope?: string): string | null => {
    const current = error();
    return current !== null && current.scope === scope ? current.message : null;
  };

  return { report, clear, messageFor };
}
