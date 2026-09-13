-- migrate:up

-- The default sort/grouping preferences lost their only reader when the
-- projection moved onto the rule cascade: grouping is the cascade's locations
-- and sort order lives on each rule and the bulk spec. Nothing else owns the
-- concept, so there is nothing to migrate forward (issue #52).
DROP TABLE app_settings;

-- migrate:down

CREATE TABLE app_settings (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  default_sort TEXT NOT NULL,
  default_grouping TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
) STRICT;
INSERT INTO app_settings (id, default_sort, default_grouping)
  VALUES (1, 'card_name', 'location_name');
