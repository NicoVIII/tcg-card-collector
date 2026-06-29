export const queryKeys = {
  importStatus: () => ["collection_import", "latest_status"] as const,
  catalogList: (offset: number, limit: number) => ["card_catalog", "list", offset, limit] as const,
  collectionList: (offset: number, limit: number) => ["collection", "list", offset, limit] as const,
  inventoryRules: () => ["inventory_planning", "rules"] as const,
  inventoryProjection: (sortBy: string, groupBy: string) =>
    ["inventory_planning", "projection", sortBy, groupBy] as const,
  settings: () => ["settings", "current"] as const,
};
