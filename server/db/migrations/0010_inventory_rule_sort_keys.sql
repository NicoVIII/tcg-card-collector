-- migrate:up

-- Each rule's cards get laid out by its own sort-key list, so a location can be
-- ordered the way its physical container is (e.g. set + collector number). Empty
-- (the default) preserves the canonical cascade order — backward compatible.
ALTER TABLE inventory_rules ADD COLUMN sort_keys TEXT NOT NULL DEFAULT '';

-- migrate:down

ALTER TABLE inventory_rules DROP COLUMN sort_keys;
