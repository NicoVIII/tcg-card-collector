-- Seed for migration_0017_placed_cards_copy_key_test.gleam.
--
-- Written against `placed_cards`'s schema as of 0016 (STRICT, no finish or
-- language column — 0016 only touched `collection`): PRIMARY KEY
-- (set_code, collector_number, location). Frozen: never edit this file to
-- match a later reshape of `placed_cards` — that would silently change what
-- the test asserts against.
--
-- Two rows share (set_code, collector_number) across two locations — the old
-- PK allows that — so a migration that collapsed them via GROUP BY would be
-- caught.
INSERT INTO placed_cards (set_code, collector_number, location, quantity) VALUES
  ('lea', '1', 'Box A / Row 1', 1),
  ('lea', '1', 'Box A / Row 2', 2),
  ('dsk', '104a', 'Box B / Row 1', 3);
