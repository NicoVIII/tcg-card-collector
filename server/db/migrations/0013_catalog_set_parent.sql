-- migrate:up
-- parent_set_code links a Scryfall child set (tokens, promos, art series, …) to
-- the parent set it belongs to; NULL for root sets. Lets a {set_family} location
-- template gather a set with all its children into one binder. Resetting
-- last_upstream_updated_at forces a set re-sync to backfill it.
ALTER TABLE catalog_sets ADD COLUMN parent_set_code TEXT;
UPDATE catalog_sync_metadata SET last_upstream_updated_at = NULL;
-- migrate:down
ALTER TABLE catalog_sets DROP COLUMN parent_set_code;
