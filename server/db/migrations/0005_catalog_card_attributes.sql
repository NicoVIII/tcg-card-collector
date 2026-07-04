-- migrate:up

-- Enrichment attributes needed by inventory planning's cascade. Catalog owns
-- these as opaque strings; planning parses them at its port boundary.
ALTER TABLE catalog_cards ADD COLUMN oracle_id TEXT NOT NULL DEFAULT '';
ALTER TABLE catalog_cards ADD COLUMN color_identity TEXT NOT NULL DEFAULT '';
ALTER TABLE catalog_cards ADD COLUMN type_line TEXT NOT NULL DEFAULT '';
ALTER TABLE catalog_cards ADD COLUMN released_at TEXT NOT NULL DEFAULT '';

-- Force the next manual refresh to do a full reload (bulk_load DELETE+reinserts)
-- so the new columns get populated for the existing catalog.
UPDATE catalog_sync_metadata SET last_upstream_updated_at = NULL;

-- migrate:down

ALTER TABLE catalog_cards DROP COLUMN oracle_id;
ALTER TABLE catalog_cards DROP COLUMN color_identity;
ALTER TABLE catalog_cards DROP COLUMN type_line;
ALTER TABLE catalog_cards DROP COLUMN released_at;
