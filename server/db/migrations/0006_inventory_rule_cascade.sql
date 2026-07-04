-- migrate:up

-- The cascade turns each rule into an ordered, copy-consuming waterfall step:
-- `position` fixes the order rules claim copies in, and `selector` says how many
-- copies of a matching card the rule takes (all / first-per-printing / first-per-oracle).
ALTER TABLE inventory_rules ADD COLUMN position INTEGER NOT NULL DEFAULT 0;
ALTER TABLE inventory_rules ADD COLUMN selector TEXT NOT NULL DEFAULT 'all';

-- Backfill positions from the order rules were listed in before this migration.
UPDATE inventory_rules
SET position = ordered.pos
FROM (
  SELECT id, ROW_NUMBER() OVER (ORDER BY location_name ASC, id ASC) AS pos
  FROM inventory_rules
) AS ordered
WHERE inventory_rules.id = ordered.id;

-- The leftover cards land in a single bulk location, laid out by a sort-key list.
-- Singleton row (id = 1), mirroring app_settings.
CREATE TABLE IF NOT EXISTS inventory_bulk_spec (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  location_name TEXT NOT NULL,
  sort_keys TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT OR IGNORE INTO inventory_bulk_spec (id, location_name, sort_keys)
VALUES (1, 'Bulk', 'color_identity,type,name');

-- migrate:down

DROP TABLE IF EXISTS inventory_bulk_spec;
ALTER TABLE inventory_rules DROP COLUMN selector;
ALTER TABLE inventory_rules DROP COLUMN position;
