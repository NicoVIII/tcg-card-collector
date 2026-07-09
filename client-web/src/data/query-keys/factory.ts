export const queryKeys = {
  catalogList: (offset: number, limit: number) => ["card_catalog", "list", offset, limit] as const,
  // Prefix of every catalogList key, for invalidating all pages at once.
  catalogListAll: () => ["card_catalog", "list"] as const,
  catalogRefreshStatus: () => ["card_catalog", "refresh_status"] as const,
  card: (set_code: string, collector_number: string) =>
    ["card_catalog", "card", set_code, collector_number] as const,
  collection: () => ["collection"] as const,
  collectionList: (offset: number, limit: number) => ["collection", "list", offset, limit] as const,
  inventoryRules: () => ["inventory_planning", "rules"] as const,
  inventoryBulkSpec: () => ["inventory_planning", "bulk_spec"] as const,
  inventoryProjection: () => ["inventory_planning", "projection"] as const,
  placedLedger: () => ["inventory_planning", "placed_ledger"] as const,
  settings: () => ["settings", "current"] as const,
  setCompletion: () => ["insights", "set_completion"] as const,
};
