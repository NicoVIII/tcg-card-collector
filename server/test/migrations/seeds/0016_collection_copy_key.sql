-- Seed for migration_0016_collection_copy_key_test.gleam.
--
-- Written against `collection`'s schema as of 0015 (STRICT, no finish or
-- language column — see 0014_strict_tables.sql): PRIMARY KEY
-- (set_code, collector_number). Frozen: never edit this file to match a
-- later reshape of `collection` — that would silently change what the test
-- asserts against.
INSERT INTO collection (set_code, collector_number, quantity) VALUES
  ('lea', '1', 1),
  ('lea', '2', 4),
  ('dsk', '104a', 2);
