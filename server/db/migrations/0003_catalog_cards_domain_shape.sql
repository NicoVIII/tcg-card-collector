-- migrate:up

DROP INDEX IF EXISTS idx_catalog_cards_oracle_id;
ALTER TABLE catalog_cards DROP COLUMN oracle_id;
ALTER TABLE catalog_cards DROP COLUMN image_normal_uri;
ALTER TABLE catalog_cards RENAME COLUMN image_small_uri TO image_uri;

-- migrate:down

ALTER TABLE catalog_cards RENAME COLUMN image_uri TO image_small_uri;
ALTER TABLE catalog_cards ADD COLUMN image_normal_uri TEXT NOT NULL DEFAULT '';
ALTER TABLE catalog_cards ADD COLUMN oracle_id TEXT NOT NULL DEFAULT '';
CREATE INDEX IF NOT EXISTS idx_catalog_cards_oracle_id ON catalog_cards(oracle_id);
