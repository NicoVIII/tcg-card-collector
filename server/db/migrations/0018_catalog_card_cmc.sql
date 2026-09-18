-- migrate:up

-- Mana value (Scryfall's cmc): nullable because a genuinely absent value (a
-- layout with no top-level cmc) is a real state, distinct from 0 (lands are a
-- legitimate zero-cost card, not "unknown").
ALTER TABLE catalog_cards ADD COLUMN cmc REAL CHECK (cmc IS NULL OR cmc >= 0);

-- Force the next manual refresh to do a full reload (bulk_load DELETE+reinserts)
-- so the new column gets populated for the existing catalog.
UPDATE catalog_sync_metadata SET last_upstream_updated_at = NULL;

-- migrate:down

ALTER TABLE catalog_cards DROP COLUMN cmc;
