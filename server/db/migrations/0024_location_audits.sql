-- migrate:up

-- Audit history (#108, ADR 0024): one row per completed location audit. The
-- latest completion per location is derived, never stored, the same as
-- Unplaced. A location is a LocationRef exactly as in placed_cards: a cascade
-- location's rendered name, or a managed location's id. completed_at is
-- RFC 3339 UTC text, so ordering by it is chronological.
CREATE TABLE location_audits (
  location_kind TEXT NOT NULL CHECK (location_kind IN ('cascade', 'managed')),
  location TEXT NOT NULL CHECK (location <> ''),
  completed_at TEXT NOT NULL CHECK (completed_at <> ''),
  PRIMARY KEY (location_kind, location, completed_at)
) STRICT;

-- migrate:down

DROP TABLE location_audits;
