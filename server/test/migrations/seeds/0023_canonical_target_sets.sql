-- Seed for migration_0023_canonical_target_sets_test.gleam.
--
-- Written against `target_sets`'s schema as of 0022 (STRICT, set_code TEXT
-- PRIMARY KEY, created_at TEXT NOT NULL, no canonical CHECK). Frozen: never
-- edit this file to match a later reshape of `target_sets`.
--
-- Three spellings of one set (the canonical one is not the earliest), one
-- padded-only code, one already canonical, and a blank one.
INSERT INTO target_sets (set_code, created_at) VALUES
  ('grn', '2026-03-01T00:00:00Z'),
  ('GRN', '2026-01-01T00:00:00Z'),
  (' Grn ', '2026-02-01T00:00:00Z'),
  ('  m11', '2026-04-01T00:00:00Z'),
  ('lea', '2026-05-01T00:00:00Z'),
  ('   ', '2026-06-01T00:00:00Z');
