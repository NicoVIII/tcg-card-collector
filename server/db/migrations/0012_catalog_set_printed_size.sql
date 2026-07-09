-- migrate:up
-- printed_size is Scryfall's official set size (the printed collector-number
-- denominator), excluding extras/variants. Nullable: Scryfall omits it for some
-- sets. Resetting last_upstream_updated_at forces a set re-sync to backfill it.
ALTER TABLE catalog_sets ADD COLUMN printed_size INTEGER;
UPDATE catalog_sync_metadata SET last_upstream_updated_at = NULL;
-- migrate:down
ALTER TABLE catalog_sets DROP COLUMN printed_size;
