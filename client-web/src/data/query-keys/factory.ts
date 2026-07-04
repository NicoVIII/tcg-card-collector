export const queryKeys = {
  importStatus: () => ["collection_import", "latest_status"] as const,
  catalogList: (offset: number, limit: number) => ["card_catalog", "list", offset, limit] as const,
  catalogRefreshStatus: () => ["card_catalog", "refresh_status"] as const,
  card: (set_code: string, collector_number: string) =>
    ["card_catalog", "card", set_code, collector_number] as const,
  collectionList: (offset: number, limit: number) => ["collection", "list", offset, limit] as const,
  inventoryRules: () => ["inventory_planning", "rules"] as const,
  inventoryBulkSpec: () => ["inventory_planning", "bulk_spec"] as const,
  inventoryProjection: () => ["inventory_planning", "projection"] as const,
  settings: () => ["settings", "current"] as const,
  setCompletion: () => ["insights", "set_completion"] as const,
};
