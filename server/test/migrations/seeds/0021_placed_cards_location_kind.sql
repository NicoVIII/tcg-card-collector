-- Seed for migration_0021_placed_cards_location_kind_test.gleam.
--
-- Written against `placed_cards`'s schema as of 0020 (STRICT, CopyKey
-- columns from 0017, no location_kind): PRIMARY KEY (set_code,
-- collector_number, finish, language, location). Frozen: never edit this
-- file to match a later reshape of `placed_cards` — that would silently
-- change what the test asserts against.
--
-- One key in two locations and two kinds of copy at one location, so a
-- migration that collapsed rows on either axis would be caught.
INSERT INTO placed_cards (set_code, collector_number, finish, language, location, quantity) VALUES
  ('lea', '1', 'nonfoil', 'en', 'Box A / Row 1', 1),
  ('lea', '1', 'nonfoil', 'en', 'Box A / Row 2', 2),
  ('lea', '1', 'foil', 'de', 'Box A / Row 2', 1),
  ('dsk', '104a', 'etched', 'ja', 'Bulk', 3);
