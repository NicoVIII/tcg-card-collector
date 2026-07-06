-- migrate:up
CREATE TABLE catalog_sets (
  set_code TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  released_at TEXT NOT NULL DEFAULT '',
  card_count INTEGER NOT NULL DEFAULT 0,
  icon_svg_uri TEXT NOT NULL DEFAULT ''
);
UPDATE catalog_sync_metadata SET last_upstream_updated_at = NULL;
-- migrate:down
DROP TABLE catalog_sets;
