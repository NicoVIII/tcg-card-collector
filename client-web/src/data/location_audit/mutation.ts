import { createMutation, useQueryClient } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import { type CompleteLocationAuditInput, completeLocationAudit } from "./request";

// Unlike a placement tick, completing an audit is rare and the page shows the
// result straight from the refetched ledger, so both reads refetch. The
// projection is untouched: an audit corrects where copies are, not where they
// should be.
export function useCompleteLocationAuditMutation() {
  const queryClient = useQueryClient();

  return createMutation(() => ({
    mutationFn: (input: CompleteLocationAuditInput) => completeLocationAudit(input),
    onSuccess: async () => {
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: queryKeys.placedLedger() }),
        queryClient.invalidateQueries({ queryKey: queryKeys.locationAudits() }),
      ]);
    },
  }));
}
