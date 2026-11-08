import { createMutation, useQueryClient } from "@tanstack/solid-query";
import { queryKeys } from "../query-keys/factory";
import {
  addToManagedLocation,
  createManagedLocation,
  deleteManagedLocation,
  removeFromManagedLocation,
  renameManagedLocation,
  type ManagedCopy,
  type ManagedLocationKind,
} from "./request";

// Every managed-location change moves copies between locations (or renames
// one the projection lists), so the projection is refetched along with the
// list. Deleting also drops the deck's placed-ledger rows.
function useInvalidateAfterChange(alsoLedger = false) {
  const queryClient = useQueryClient();
  return async () => {
    await queryClient.invalidateQueries({ queryKey: queryKeys.managedLocations() });
    await queryClient.invalidateQueries({ queryKey: queryKeys.inventoryProjection() });
    if (alsoLedger) {
      await queryClient.invalidateQueries({ queryKey: queryKeys.placedLedger() });
    }
  };
}

export function useCreateManagedLocationMutation() {
  const onSuccess = useInvalidateAfterChange();
  return createMutation(() => ({
    mutationFn: (location: { id: string; name: string; kind: ManagedLocationKind }) =>
      createManagedLocation(location),
    onSuccess,
  }));
}

export function useRenameManagedLocationMutation() {
  const onSuccess = useInvalidateAfterChange();
  return createMutation(() => ({
    mutationFn: (rename: { id: string; name: string }) =>
      renameManagedLocation(rename.id, rename.name),
    onSuccess,
  }));
}

export function useDeleteManagedLocationMutation() {
  const onSuccess = useInvalidateAfterChange(true);
  return createMutation(() => ({
    mutationFn: (id: string) => deleteManagedLocation(id),
    onSuccess,
  }));
}

export function useAddToManagedLocationMutation() {
  const onSuccess = useInvalidateAfterChange();
  return createMutation(() => ({
    mutationFn: (change: { id: string; copies: ManagedCopy[] }) =>
      addToManagedLocation(change.id, change.copies),
    onSuccess,
  }));
}

export function useRemoveFromManagedLocationMutation() {
  const onSuccess = useInvalidateAfterChange();
  return createMutation(() => ({
    mutationFn: (change: { id: string; copies: ManagedCopy[] }) =>
      removeFromManagedLocation(change.id, change.copies),
    onSuccess,
  }));
}
