-- migrate:up
ALTER TABLE collection_snapshot DROP COLUMN card_name;

-- migrate:down
ALTER TABLE collection_snapshot ADD COLUMN card_name TEXT NOT NULL DEFAULT '';
